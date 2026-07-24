"""WhisperX diarization FastAPI application.

Provides speaker-aware transcription with word-level alignment and
pyannote-based speaker diarization. Accepts audio uploads and returns
structured JSON with timestamped segments and speaker labels.

GPU model lifecycle: ASR is loaded, transcribes, then unloaded before
the diarization pipeline is loaded. Only one model is resident on the
GPU at any time. One-job concurrency is enforced via a threading lock.

Tested against whisperx 3.8.6 and pyannote-audio 4.0.7 from the
pinned nixpkgs flake. DiarizationPipeline must be imported from
whisperx.diarize (not whisperx) and uses ``token=`` (not
``use_auth_token=``).
"""

import argparse
import asyncio
import json
import logging
import os
import tempfile
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from .cache import EmbeddingCache
from .embeddings import EmbeddingExtractor, ShortSegmentSkipped
from .enrollment import MIN_ENROLLMENT_SAMPLES, EnrollmentStore
from .identity import cosine_similarity
from .models import BusyError, ModelManager

logger = logging.getLogger("diarization-server")

# ── Limits ──────────────────────────────────────────────────────────
MAX_UPLOAD_BYTES = 50 * 1024 * 1024  # 50 MB
MAX_DURATION_SECONDS = 7200  # 2 hour (conservative bound)
SUPPORTED_FORMATS = {".wav", ".mp3", ".m4a", ".ogg", ".flac", ".webm", ".mp4"}
ENROLLMENT_DIR = Path("/var/lib/llama-swap/diarization/enrollment")
EMBEDDING_CACHE_DIR = Path("/var/lib/llama-swap/diarization/embedding-cache")
# Default diarization model (community edition, no HF gated access needed).
DEFAULT_DIARIZATION_MODEL = "pyannote/speaker-diarization-community-1"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="WhisperX diarization server for llama-swap"
    )
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--model-id", default="whisper-diarization")
    parser.add_argument("--device", default="cuda")
    parser.add_argument("--compute-type", default="float16")
    parser.add_argument("--download-root", default=None)
    parser.add_argument("--language", default=None)
    parser.add_argument(
        "--hf-token-path",
        default=None,
        help=(
            "Path to file containing HuggingFace token for gated pyannote "
            "models. Not required for the default community diarization model."
        ),
    )
    parser.add_argument(
        "--diarization-model",
        default=DEFAULT_DIARIZATION_MODEL,
        help=(
            "HuggingFace model ID for diarization. "
            f"Default: {DEFAULT_DIARIZATION_MODEL}"
        ),
    )
    parser.add_argument(
        "--enrollment-dir",
        default=str(ENROLLMENT_DIR),
        help="Persistent directory for speaker enrollment metadata",
    )
    parser.add_argument(
        "--similarity-threshold",
        type=float,
        default=0.75,
        help=(
            "Cosine similarity threshold for candidate matching (default: 0.75). "
            "Higher = more conservative. Range [0.5, 0.95]."
        ),
    )
    parser.add_argument(
        "--ambiguity-margin",
        type=float,
        default=0.05,
        help=(
            "Margin below threshold at which candidates are flagged as ambiguous "
            "(default: 0.05). E.g. with threshold=0.75 and margin=0.05, scores in "
            "[0.70, 0.75) are flagged ambiguous."
        ),
    )
    return parser


def _build_cache_sync(
    temp_audio: str,
    segments: list[dict],
    recording_name: str,
    extractor: EmbeddingExtractor,
) -> dict:
    """Synchronous cache build: decode audio ONCE, then embed segments.

    Runs in a worker thread via asyncio.to_thread so the event loop is not
    blocked. CPU decode happens once; per-segment GPU work is serialized
    via extractor._gpu_lock, allowing different recordings to overlap their
    CPU decode while CUDA use remains safe.

    Returns dict with segment_embeddings, label_embeddings, excluded info,
    and segments_skipped_short count.
    """
    import torchaudio

    # Decode full audio exactly ONCE per cache request
    signal, sample_rate = torchaudio.load(temp_audio)
    if signal.shape[0] > 1:
        signal = signal.mean(dim=0, keepdim=True)

    logger.info(
        "Cache build %s: decoded audio once (%.1fs, sr=%d, %d segments to process)",
        recording_name,
        signal.shape[1] / sample_rate,
        sample_rate,
        len(segments),
    )

    segment_embeddings = []
    label_embeddings = {}  # label -> list of embeddings
    excluded_segments = []  # track genuine failures with reasons
    label_failure_counts = {}  # label -> count of failed segments
    segments_skipped_short = 0  # expected skips, not failures

    for seg in segments:
        label = seg.get("speaker", "UNKNOWN")
        start = float(seg.get("start", 0))
        end = float(seg.get("end", 0))

        if end <= start:
            excluded_segments.append({
                "label": label,
                "start": start,
                "end": end,
                "reason": "invalid_time_range",
            })
            label_failure_counts[label] = label_failure_counts.get(label, 0) + 1
            continue

        # Pre-filter by duration BEFORE calling extractor — avoids
        # GPU path for segments that cannot produce stable embeddings.
        segment_duration = end - start
        if segment_duration < extractor.MIN_SEGMENT_DURATION:
            segments_skipped_short += 1
            logger.info(
                "Skipping short segment %s [%.2f-%.2f] (%.2fs < %.2fs)",
                recording_name, start, end,
                segment_duration, extractor.MIN_SEGMENT_DURATION,
            )
            continue

        try:
            # Use waveform-based extraction: no re-decode, just slice + GPU
            emb = extractor.extract_embedding_from_waveform(
                signal, sample_rate, start, end
            )
            segment_embeddings.append({
                "label": label,
                "start": start,
                "end": end,
                "duration": end - start,
                "embedding": emb.tolist(),
            })
            if label not in label_embeddings:
                label_embeddings[label] = []
            label_embeddings[label].append(emb)
        except ShortSegmentSkipped:
            # Defense in depth — extractor's own guard caught it.
            # Count as skip, not failure. Extractor already logged it.
            segments_skipped_short += 1
        except Exception as e:
            # Genuine extraction failure (CUDA/audio error)
            excluded_segments.append({
                "label": label,
                "start": start,
                "end": end,
                "reason": "extraction_failed",
                "error": str(e),
            })
            label_failure_counts[label] = label_failure_counts.get(label, 0) + 1
            logger.error(
                "Failed to extract embedding for %s [%.2f-%.2f]: %s",
                recording_name, start, end, e,
            )

    return {
        "segment_embeddings": segment_embeddings,
        "label_embeddings": label_embeddings,
        "excluded_segments": excluded_segments,
        "label_failure_counts": label_failure_counts,
        "segments_skipped_short": segments_skipped_short,
    }


def create_app(args: argparse.Namespace) -> FastAPI:
    manager = ModelManager(args)
    enrollment_dir = Path(args.enrollment_dir)
    enrollment_store = EnrollmentStore(enrollment_dir)
    # The embedding model is public; no HF token is needed.
    embedding_extractor = EmbeddingExtractor()
    # Embedding cache lives adjacent to enrollment, same owner-only protection.
    cache_dir = enrollment_dir.parent / "embedding-cache"
    embedding_cache = EmbeddingCache(cache_dir, embedding_extractor._model_id)
    # Per-recording locks to prevent duplicate simultaneous cache builds.
    # Keyed by recording_name; asyncio.Lock ensures only one build per recording
    # while allowing different recordings to proceed concurrently.
    recording_locks: dict[str, asyncio.Lock] = {}

    # Validate threshold parameters
    if not (0.5 <= args.similarity_threshold <= 0.95):
        raise ValueError(
            f"similarity_threshold must be in [0.5, 0.95], got {args.similarity_threshold}"
        )
    if not (0.0 <= args.ambiguity_margin <= 0.2):
        raise ValueError(
            f"ambiguity_margin must be in [0.0, 0.2], got {args.ambiguity_margin}"
        )

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.manager = manager
        app.state.model_id = args.model_id
        app.state.device = args.device
        app.state.enrollment_store = enrollment_store
        app.state.embedding_extractor = embedding_extractor
        app.state.embedding_cache = embedding_cache
        app.state.similarity_threshold = args.similarity_threshold
        app.state.ambiguity_margin = args.ambiguity_margin
        enrollment_dir.mkdir(parents=True, exist_ok=True)
        cache_dir.mkdir(parents=True, exist_ok=True)
        yield

    app = FastAPI(lifespan=lifespan)

    # ── Health / Model routes ────────────────────────────────

    @app.get("/")
    async def root():
        return {
            "status": "ok",
            "model": app.state.model_id,
            "device": app.state.device,
        }

    @app.get("/health")
    @app.get("/v1/health")
    async def health():
        return {"status": "ok", "device": app.state.device}

    @app.get("/models")
    @app.get("/v1/models")
    async def models():
        return {
            "object": "list",
            "data": [
                {
                    "id": app.state.model_id,
                    "object": "model",
                    "owned_by": "local",
                }
            ],
        }

    # ── Transcription + Diarization ──────────────────────────

    @app.post("/audio/transcriptions")
    @app.post("/v1/audio/transcriptions")
    async def transcriptions(
        file: UploadFile = File(...),
        model: str | None = Form(default=None),
        language: str | None = Form(default=None),
        min_speakers: int | None = Form(default=None),
        max_speakers: int | None = Form(default=None),
        num_speakers: int | None = Form(default=None),
        identity_mode: str | None = Form(default="off"),
        response_format: str | None = Form(default=None),
    ):
        # ── Input validation ─────────────────────────────────
        if model and model != app.state.model_id:
            raise HTTPException(
                status_code=400,
                detail=(f"Model must be '{app.state.model_id}', got '{model}'"),
            )

        if response_format and response_format != "diarized_json":
            raise HTTPException(
                status_code=400,
                detail=(
                    "Only 'diarized_json' response format is supported, "
                    f"got '{response_format}'"
                ),
            )

        valid_identity_modes = {"off", "candidates"}
        if identity_mode and identity_mode not in valid_identity_modes:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"identity_mode must be one of {valid_identity_modes}, "
                    f"got '{identity_mode}'"
                ),
            )

        if num_speakers is not None and (
            min_speakers is not None or max_speakers is not None
        ):
            raise HTTPException(
                status_code=400,
                detail="Cannot specify both num_speakers and min/max_speakers",
            )

        for param_name, param_val in [
            ("min_speakers", min_speakers),
            ("max_speakers", max_speakers),
            ("num_speakers", num_speakers),
        ]:
            if param_val is not None and param_val < 1:
                raise HTTPException(
                    status_code=400,
                    detail=f"{param_name} must be >= 1, got {param_val}",
                )

        # ── File validation ──────────────────────────────────
        suffix = Path(file.filename or "audio.wav").suffix or ".wav"
        if suffix.lower() not in SUPPORTED_FORMATS:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Unsupported audio format: {suffix}. "
                    f"Supported: {sorted(SUPPORTED_FORMATS)}"
                ),
            )

        audio_bytes = await file.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio file")
        if len(audio_bytes) > MAX_UPLOAD_BYTES:
            raise HTTPException(
                status_code=413,
                detail=(
                    f"Audio file too large: {len(audio_bytes)} bytes "
                    f"(max {MAX_UPLOAD_BYTES})"
                ),
            )

        warnings: list[str] = []

        # ── Write to temp file ───────────────────────────────
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                tmp.write(audio_bytes)
                temp_path = tmp.name

            try:
                phase_ctx = manager.acquire()
            except BusyError as exc:
                raise HTTPException(
                    status_code=503,
                    detail=str(exc),
                ) from exc

            with phase_ctx as phase:
                import whisperx

                # ── Phase 1: ASR transcription ──────────
                logger.info("Phase 1: Transcribing with WhisperX ASR")
                phase._ensure_asr()

                result = phase._asr_model.transcribe(
                    temp_path,
                    batch_size=16,
                    language=language,
                )

                detected_language = result.get("language", language or "unknown")
                logger.info(
                    "Transcription complete: %d segments, lang=%s",
                    len(result["segments"]),
                    detected_language,
                )

                # Unload ASR before loading alignment
                phase._unload_asr()

                # ── Phase 2: Word-level alignment ───────
                logger.info("Phase 2: Aligning segments")
                phase._ensure_align(detected_language)

                result = whisperx.align(
                    result["segments"],
                    phase._align_model,
                    phase._align_metadata,
                    temp_path,
                    device=app.state.device,
                    return_char_alignments=False,
                )

                # Unload alignment before loading diarization
                phase._unload_align()

                # ── Phase 3: Diarization ────────────────
                logger.info("Phase 3: Diarizing audio")
                phase._ensure_diarize()

                diarize_kwargs: dict = {}
                if num_speakers is not None:
                    diarize_kwargs["num_speakers"] = num_speakers
                if min_speakers is not None:
                    diarize_kwargs["min_speakers"] = min_speakers
                if max_speakers is not None:
                    diarize_kwargs["max_speakers"] = max_speakers

                diarize_result = phase._diarize_pipeline(
                    temp_path,
                    **diarize_kwargs,
                )

                # ── Phase 4: Assign speakers ────────────
                logger.info("Phase 4: Assigning speaker labels")
                result = whisperx.assign_word_speakers(diarize_result, result)

                # ── Build response ──────────────────────
                segments = result.get("segments", [])

                # Extract unique speakers in order of appearance
                speaker_order: list[str] = []
                seen: set[str] = set()
                for seg in segments:
                    spk = seg.get("speaker", "SPEAKER_00")
                    if spk not in seen:
                        speaker_order.append(spk)
                        seen.add(spk)

                # Duration from last segment end
                duration = None
                if segments:
                    duration = max(seg.get("end", 0) for seg in segments)

                # Build output segments
                output_segments = []
                for seg in segments:
                    output_segments.append(
                        {
                            "start": round(seg.get("start", 0), 3),
                            "end": round(seg.get("end", 0), 3),
                            "text": seg.get("text", "").strip(),
                            "speaker": seg.get("speaker", "SPEAKER_00"),
                        }
                    )

                full_text = " ".join(s["text"] for s in output_segments).strip()

                # Identity mode handling
                identity_result = {
                    "mode": identity_mode or "off",
                    "status": "not_requested",
                }

                if identity_mode == "candidates":
                    # Perform candidate matching for each unique speaker
                    speaker_candidates = {}
                    matching_status = "ok"
                    matching_warnings = []

                    try:
                        # Extract embeddings for each unique speaker
                        for speaker_label in speaker_order:
                            # Collect all segments for this speaker
                            speaker_segments = [
                                seg for seg in segments
                                if seg.get("speaker") == speaker_label
                            ]

                            if not speaker_segments:
                                continue

                            # Extract audio spans for this speaker and compute embeddings
                            # For simplicity, we'll use the first substantial segment
                            # (ideally we'd concatenate, but that requires audio processing)
                            sample_embedding = None

                            for seg in speaker_segments:
                                start = seg.get("start", 0)
                                end = seg.get("end", 0)
                                duration = end - start

                                # Skip very short segments (< 1 second)
                                if duration < 1.0:
                                    continue

                                # Extract embedding from this segment
                                # Note: This requires the audio file to still be available
                                # and we need to extract the specific time range
                                try:
                                    import torchaudio

                                    # Load full audio and extract segment
                                    signal, sample_rate = torchaudio.load(temp_path)

                                    # Convert sample times to sample indices
                                    start_sample = int(start * sample_rate)
                                    end_sample = int(end * sample_rate)

                                    # Extract segment
                                    if signal.shape[0] > 1:
                                        signal = signal.mean(dim=0, keepdim=True)

                                    segment_signal = signal[:, start_sample:end_sample]

                                    # Save segment to temp file for embedding extraction
                                    with tempfile.NamedTemporaryFile(
                                        delete=False, suffix=".wav"
                                    ) as seg_tmp:
                                        seg_temp_path = seg_tmp.name
                                        torchaudio.save(
                                            seg_temp_path,
                                            segment_signal,
                                            sample_rate,
                                        )

                                    try:
                                        sample_embedding = embedding_extractor.extract_embedding(
                                            seg_temp_path
                                        )
                                        break  # Use first valid embedding
                                    finally:
                                        if os.path.exists(seg_temp_path):
                                            os.unlink(seg_temp_path)

                                except Exception as e:
                                    logger.warning(
                                        "Failed to extract embedding for speaker %s: %s",
                                        speaker_label,
                                        e,
                                    )
                                    continue

                            if sample_embedding is None:
                                speaker_candidates[speaker_label] = {
                                    "status": "extraction_failed",
                                    "candidates": [],
                                    "reason": "Could not extract speaker embedding from audio segments",
                                }
                                continue

                            # Compare against all enrolled candidates
                            candidates_list = []
                            threshold = app.state.similarity_threshold
                            margin = app.state.ambiguity_margin

                            for candidate in enrollment_store.list_candidates():
                                candidate_id = candidate["person_id"]
                                candidate_embeddings = enrollment_store.get_embeddings(candidate_id)

                                if not candidate_embeddings:
                                    continue

                                # Compute similarity against each enrolled embedding
                                # and use the maximum (best match)
                                max_similarity = max(
                                    cosine_similarity(sample_embedding, emb)
                                    for emb in candidate_embeddings
                                )

                                # Determine match status
                                if max_similarity >= threshold:
                                    match_status = "match"
                                elif max_similarity >= (threshold - margin):
                                    match_status = "ambiguous"
                                else:
                                    match_status = "below_threshold"

                                candidates_list.append({
                                    "person_id": candidate_id,
                                    "display_name": candidate["display_name"],
                                    "similarity": round(max_similarity, 4),
                                    "match_status": match_status,
                                    "threshold": threshold,
                                })

                            # Sort by similarity descending
                            candidates_list.sort(key=lambda c: c["similarity"], reverse=True)

                            speaker_candidates[speaker_label] = {
                                "status": "ok",
                                "candidates": candidates_list,
                            }

                        identity_result = {
                            "mode": "candidates",
                            "status": matching_status,
                            "speaker_candidates": speaker_candidates,
                            "threshold": app.state.similarity_threshold,
                            "ambiguity_margin": app.state.ambiguity_margin,
                            "note": (
                                "Candidates are advisory only and based on voice similarity. "
                                "Do not treat as confirmed identity. Review manually before use."
                            ),
                        }

                        if matching_warnings:
                            warnings.extend(matching_warnings)

                    except Exception as e:
                        logger.error("Candidate matching failed: %s", e)
                        identity_result = {
                            "mode": "candidates",
                            "status": "matching_failed",
                            "error": str(e),
                            "note": "Candidate matching failed. Only anonymous speaker labels are returned.",
                        }
                        warnings.append(
                            f"Candidate matching failed: {e}. "
                            "Only anonymous speaker labels are returned."
                        )

                return JSONResponse(
                    {
                        "text": full_text,
                        "language": detected_language,
                        "duration": (
                            round(duration, 3) if duration is not None else None
                        ),
                        "segments": output_segments,
                        "speakers": speaker_order,
                        "identity": identity_result,
                        "warnings": warnings,
                    }
                )

        finally:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)

    # ── Enrollment endpoints ───────────────────────────────────

    @app.post("/v1/identity/enroll")
    async def enroll_person(
        consent: bool = Form(...),
        person_id: str = Form(...),
        display_name: str = Form(...),
    ):
        """Initialize enrollment for a person.

        Requires explicit consent flag. Creates metadata record but does not
        add any samples yet. Use /v1/identity/samples to add audio.

        Returns 400 if consent not granted or person_id invalid.
        Returns 409 if enrollment already exists.
        """
        # Validate person_id format
        if not person_id or not person_id.strip():
            raise HTTPException(
                status_code=400,
                detail="person_id is required and cannot be empty",
            )

        if "/" in person_id or ".." in person_id:
            raise HTTPException(
                status_code=400,
                detail="person_id contains invalid characters",
            )

        # Validate consent
        if not consent:
            raise HTTPException(
                status_code=400,
                detail="Consent must be granted to enroll. Set consent=true.",
            )

        if not display_name or not display_name.strip():
            raise HTTPException(
                status_code=400,
                detail="display_name is required and cannot be empty",
            )

        try:
            metadata = enrollment_store.initialize_enrollment(
                person_id=person_id,
                display_name=display_name.strip(),
                consent_granted=consent,
            )
            return {
                "status": "initialized",
                "person_id": metadata["person_id"],
                "display_name": metadata["display_name"],
                "consent_granted": metadata["consent_granted"],
                "consent_timestamp": metadata["consent_timestamp"],
                "samples_count": 0,
                "candidate_eligible": False,
                "message": (
                    f"Enrollment initialized for {person_id}. "
                    f"Add {MIN_ENROLLMENT_SAMPLES} or more audio samples via "
                    f"/v1/identity/samples to become candidate-eligible."
                ),
            }
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except RuntimeError as e:
            raise HTTPException(status_code=409, detail=str(e))

    @app.post("/v1/identity/samples")
    async def upload_sample(
        person_id: str = Form(...),
        file: UploadFile = File(...),
    ):
        """Upload an audio sample for an enrolled person.

        Extracts speaker embedding (CUDA-only) and stores it. Does not retain
        raw audio. Requires enrollment to be initialized first.

        Returns 400 if audio invalid or extraction fails.
        Returns 404 if enrollment not found.
        """
        # Validate person_id exists
        metadata = enrollment_store.get_metadata(person_id)
        if metadata is None:
            raise HTTPException(
                status_code=404,
                detail=f"Enrollment not found for {person_id}. Initialize first via /v1/identity/enroll.",
            )

        # Validate file
        suffix = Path(file.filename or "audio.wav").suffix or ".wav"
        if suffix.lower() not in SUPPORTED_FORMATS:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Unsupported audio format: {suffix}. "
                    f"Supported: {sorted(SUPPORTED_FORMATS)}"
                ),
            )

        audio_bytes = await file.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio file")

        if len(audio_bytes) > MAX_UPLOAD_BYTES:
            raise HTTPException(
                status_code=413,
                detail=(
                    f"Audio file too large: {len(audio_bytes)} bytes "
                    f"(max {MAX_UPLOAD_BYTES})"
                ),
            )

        # Minimum size guard (reject very short/corrupt files)
        if len(audio_bytes) < 1000:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Audio file too small: {len(audio_bytes)} bytes. "
                    "Minimum ~1 second of audio required."
                ),
            )

        # Write to temp file for extraction
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                tmp.write(audio_bytes)
                temp_path = tmp.name

            # Extract embedding (CUDA-only, lazy-loaded)
            try:
                embedding = embedding_extractor.extract_embedding(temp_path)
            except RuntimeError as e:
                raise HTTPException(
                    status_code=500,
                    detail=(
                        f"Embedding extraction failed: {e}. "
                        "The audio file may be corrupt, too short, or contain no speech."
                    ),
                )

            # Store embedding (raw audio is NOT retained)
            updated_metadata = enrollment_store.add_sample(person_id, embedding)

            return {
                "status": "sample_added",
                "person_id": person_id,
                "samples_count": updated_metadata["samples_count"],
                "candidate_eligible": updated_metadata["candidate_eligible"],
                "embedding_shape": list(embedding.shape),
                "message": (
                    f"Sample added. {updated_metadata['samples_count']} total samples. "
                    + (
                        "Candidate-eligible!"
                        if updated_metadata["candidate_eligible"]
                        else f"Need {MIN_ENROLLMENT_SAMPLES - updated_metadata['samples_count']} more samples for candidate eligibility."
                    )
                ),
            }
        finally:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)

    @app.get("/v1/identity/candidates")
    async def list_candidates():
        """List enrolled speakers who meet the sample threshold.

        Returns list of person_ids eligible for candidate matching.
        Does not perform any matching - use /v1/audio/transcriptions with
        identity_mode=candidates to get per-segment candidate suggestions.
        """
        candidates = enrollment_store.list_candidates()

        return {
            "status": "ok",
            "candidates": candidates,
            "min_samples_required": MIN_ENROLLMENT_SAMPLES,
            "total_enrolled": len(list(enrollment_dir.iterdir())) if enrollment_dir.exists() else 0,
        }

    @app.get("/v1/identity/status/{person_id}")
    async def enrollment_status(person_id: str):
        """Get enrollment status for a specific person.

        Returns metadata including sample count and candidate eligibility.
        Returns 404 if not found.
        """
        metadata = enrollment_store.get_metadata(person_id)
        if metadata is None:
            raise HTTPException(
                status_code=404,
                detail=f"Enrollment not found for {person_id}",
            )

        return metadata

    # ── Embedding Cache Endpoints ─────────────────────────────

    @app.post("/v1/identity/cache/build")
    async def build_embedding_cache(
        audio: UploadFile = File(...),
        transcript: UploadFile = File(...),
        recording_name: str = Form(...),
    ):
        """Build or update embedding cache for a recording.

        Receives audio + canonical transcript JSON, extracts embeddings for
        diarized segments, computes per-label prototypes, stores protected cache.
        Never calls ASR/alignment/diarization.

        Concurrency: audio is decoded exactly ONCE per request. CPU decode work
        runs in a worker thread (asyncio.to_thread) so the event loop is not
        blocked. GPU work (resample + SpeechBrain forward) is serialized via
        the extractor's instance-level GPU lock. Per-recording asyncio locks
        prevent duplicate simultaneous builds for the same recording while
        allowing different recordings to proceed concurrently.

        Returns status: built|hit|stale|failed, plus counts.
        """
        # Validate transcript is JSON
        if not transcript.filename or not transcript.filename.endswith(".json"):
            raise HTTPException(400, "transcript must be a .json file")

        # Read transcript JSON
        try:
            transcript_bytes = await transcript.read()
            if len(transcript_bytes) > MAX_UPLOAD_BYTES:
                raise HTTPException(413, "transcript too large")
            transcript_data = json.loads(transcript_bytes)
        except json.JSONDecodeError as e:
            raise HTTPException(400, f"Invalid transcript JSON: {e}")

        # Extract segments
        segments = transcript_data.get("segments", [])
        if not segments:
            raise HTTPException(400, "transcript has no segments")

        # Compute revision inputs
        transcript_sha = embedding_cache._sha256_bytes(transcript_bytes)
        segment_set_hash = embedding_cache._segment_set_hash(segments)

        # Write audio to temp file for embedding extraction
        audio_sha = None
        temp_audio = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".audio") as tmp:
                audio_content = await audio.read()
                if len(audio_content) > MAX_UPLOAD_BYTES:
                    raise HTTPException(413, "audio too large")
                tmp.write(audio_content)
                temp_audio = tmp.name

            audio_sha = embedding_cache._sha256_file(Path(temp_audio))

            # Per-recording lock: prevents duplicate simultaneous builds for
            # the same recording_name. Different recordings proceed concurrently.
            lock = recording_locks.setdefault(recording_name, asyncio.Lock())
            async with lock:
                # Re-check cache after acquiring lock (another request may have
                # built it while we were waiting)
                lookup = embedding_cache.lookup(audio_sha, transcript_sha, segment_set_hash)
                if lookup["status"] == "hit":
                    return {
                        "status": "hit",
                        "cache_id": lookup["cache_id"],
                        "recording_name": recording_name,
                        "label_count": lookup["manifest"].get("label_count", 0),
                        "segment_count": lookup["manifest"].get("segment_count", 0),
                        "segments_skipped_short": lookup["manifest"].get("segments_skipped_short", 0),
                    }

                # Decode + embed in worker thread (CPU decode once, GPU serialized)
                build_result = await asyncio.to_thread(
                    _build_cache_sync,
                    temp_audio, segments, recording_name, embedding_extractor,
                )

                segment_embeddings = build_result["segment_embeddings"]
                label_embeddings = build_result["label_embeddings"]
                excluded_segments = build_result["excluded_segments"]
                label_failure_counts = build_result["label_failure_counts"]
                segments_skipped_short = build_result["segments_skipped_short"]

                # Check if we have any usable embeddings at all
                if not segment_embeddings:
                    raise HTTPException(
                        500,
                        {
                            "error": "no_usable_embeddings",
                            "message": "No embeddings extracted from any segment",
                            "excluded_count": len(excluded_segments),
                            "excluded_segments": excluded_segments[:20],  # cap for response size
                        },
                    )

                # Compute per-label prototypes (mean of normalized embeddings, re-normalized)
                prototypes = {}
                excluded_labels = []  # labels with no usable segments
                for label, embs in label_embeddings.items():
                    if not embs:
                        # This shouldn't happen given the logic above, but handle defensively
                        excluded_labels.append({
                            "label": label,
                            "reason": "no_valid_segments",
                            "failed_count": label_failure_counts.get(label, 0),
                        })
                        continue
                    mean_emb = np.mean(embs, axis=0)
                    norm = np.linalg.norm(mean_emb)
                    if norm > 0:
                        mean_emb = mean_emb / norm
                    prototypes[label] = {
                        "embedding": mean_emb.tolist(),
                        "segment_count": len(embs),
                        "total_duration": sum(
                            s["duration"] for s in segment_embeddings if s["label"] == label
                        ),
                    }

                # Identify labels that had only failures (no successful embeddings)
                all_labels_in_segments = set(seg.get("speaker", "UNKNOWN") for seg in segments)
                labels_with_prototypes = set(prototypes.keys())
                labels_without_prototypes = all_labels_in_segments - labels_with_prototypes
                for label in labels_without_prototypes:
                    excluded_labels.append({
                        "label": label,
                        "reason": "all_segments_failed",
                        "failed_count": label_failure_counts.get(label, 0),
                    })

                # Fail if zero usable label prototypes remain
                if not prototypes:
                    raise HTTPException(
                        500,
                        {
                            "error": "no_usable_label_prototypes",
                            "message": "All labels excluded; no usable prototypes remain",
                            "excluded_labels": excluded_labels,
                            "excluded_segment_count": len(excluded_segments),
                        },
                    )

                # Store cache with exclusion metadata
                exclusion_metadata = {
                    "excluded_segment_count": len(excluded_segments),
                    "excluded_segments": excluded_segments,
                    "excluded_label_count": len(excluded_labels),
                    "excluded_labels": excluded_labels,
                    "segments_skipped_short": segments_skipped_short,
                }
                result = embedding_cache.store(
                    audio_sha=audio_sha,
                    transcript_sha=transcript_sha,
                    segment_set_hash=segment_set_hash,
                    prototypes=prototypes,
                    segment_embeddings=segment_embeddings,
                    recording_name=recording_name,
                    exclusion_metadata=exclusion_metadata,
                )

                return {
                    "status": result["status"],
                    "cache_id": result["cache_id"],
                    "recording_name": recording_name,
                    "label_count": len(prototypes),
                    "segment_count": len(segment_embeddings),
                    "segments_skipped_short": segments_skipped_short,
                    "excluded_segment_count": len(excluded_segments),
                    "excluded_label_count": len(excluded_labels),
                    "excluded_labels": excluded_labels,
                }

        finally:
            if temp_audio and os.path.exists(temp_audio):
                os.unlink(temp_audio)

    @app.post("/v1/identity/cache/candidates")
    async def get_candidates_from_cache(
        person_id: str = Form(...),
        cache_refs: str = Form(...),  # JSON list of {cache_id, recording_name}
    ):
        """Get candidate matches from cached embeddings.

        Compares person's enrolled centroid to recording label prototypes.
        Returns review-only candidates with supporting evidence.
        Never mutates mappings.

        Args:
            person_id: Enrolled person ID
            cache_refs: JSON list of {cache_id, recording_name}

        Returns:
            List of candidates with scores, supporting segments, skipped states.
        """
        # Validate person exists and is eligible
        metadata = enrollment_store.get_metadata(person_id)
        if not metadata:
            raise HTTPException(404, f"Person not found: {person_id}")
        if not metadata.get("candidate_eligible"):
            raise HTTPException(
                400,
                f"Person {person_id} not eligible (need {MIN_ENROLLMENT_SAMPLES}+ samples)",
            )

        # Parse cache refs
        try:
            refs = json.loads(cache_refs)
            if not isinstance(refs, list):
                raise ValueError("cache_refs must be a list")
        except Exception as e:
            raise HTTPException(400, f"Invalid cache_refs JSON: {e}")

        # Compute person centroid
        person_embeddings = enrollment_store.get_embeddings(person_id)
        if not person_embeddings:
            raise HTTPException(400, f"No embeddings for {person_id}")
        centroid = np.mean(person_embeddings, axis=0)
        norm = np.linalg.norm(centroid)
        if norm > 0:
            centroid = centroid / norm

        threshold = app.state.similarity_threshold
        margin = app.state.ambiguity_margin

        candidates = []
        skipped = []

        for ref in refs:
            cache_id = ref.get("cache_id")
            recording_name = ref.get("recording_name", "unknown")

            if not cache_id:
                skipped.append({
                    "recording_name": recording_name,
                    "reason": "missing_cache_id",
                })
                continue

            cache_entry = embedding_cache.load(cache_id)
            if not cache_entry:
                skipped.append({
                    "recording_name": recording_name,
                    "cache_id": cache_id,
                    "reason": "cache_missing",
                })
                continue

            prototypes = cache_entry["prototypes"].get("prototypes", {})

            # Compare each label prototype to person centroid
            for label, proto in prototypes.items():
                proto_emb = np.array(proto["embedding"])
                score = cosine_similarity(centroid, proto_emb)

                if score >= threshold:
                    # Find supporting segments
                    supporting = [
                        {
                            "start": s["start"],
                            "end": s["end"],
                            "duration": s["duration"],
                        }
                        for s in cache_entry["prototypes"].get("segments", [])
                        if s["label"] == label
                    ]

                    ambiguous = score < (threshold + margin)

                    candidates.append({
                        "recording_name": recording_name,
                        "cache_id": cache_id,
                        "speaker_label": label,
                        "score": score,
                        "ambiguous": ambiguous,
                        "supporting_segments": supporting,
                        "segment_count": proto.get("segment_count", 0),
                        "total_duration": proto.get("total_duration", 0),
                    })

        return {
            "person_id": person_id,
            "candidates": candidates,
            "skipped": skipped,
            "threshold": threshold,
            "margin": margin,
        }

    @app.get("/v1/identity/inventory")
    async def enrollment_inventory():
        """List all enrolled persons with sample counts, eligibility, updated time.

        For repo to reconcile wiki/person inventory status from authoritative server state.
        """
        persons = enrollment_store.list_persons()
        return {
            "persons": persons,
            "min_samples_required": MIN_ENROLLMENT_SAMPLES,
            "total": len(persons),
        }

    return app


def main():
    args = build_parser().parse_args()
    uvicorn.run(
        create_app(args),
        host=args.host,
        port=args.port,
        log_level="info",
    )


if __name__ == "__main__":
    main()
