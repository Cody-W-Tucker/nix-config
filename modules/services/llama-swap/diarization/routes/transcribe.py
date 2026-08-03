"""Transcription + inline candidate-matching endpoint.

Owns the /audio/transcriptions and /v1/audio/transcriptions routes.
The identity_mode=candidates branch performs on-the-fly speaker
embedding extraction and comparison against the enrollment store.
"""

import logging
import os
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from ..identity import cosine_similarity
from ..models import BusyError

logger = logging.getLogger("diarization-server")


def _match_speakers_to_candidates(
    speaker_order: list[str],
    segments: list[dict],
    temp_path: str,
    embedding_extractor,
    enrollment_store,
    threshold: float,
    margin: float,
) -> dict:
    """Run identity-mode=candidates matching for each unique speaker.

    Returns a dict shaped like the final ``identity`` response payload.
    On extraction failure, returns a dict with status ``matching_failed``
    and an ``error`` key. Callers merge ``warnings`` into the response.
    """
    speaker_candidates: dict = {}
    matching_warnings: list[str] = []

    try:
        for speaker_label in speaker_order:
            speaker_segments = [
                seg for seg in segments
                if seg.get("speaker") == speaker_label
            ]

            if not speaker_segments:
                continue

            sample_embedding = None

            for seg in speaker_segments:
                start = seg.get("start", 0)
                end = seg.get("end", 0)
                duration = end - start

                if duration < 1.0:
                    continue

                try:
                    import torchaudio

                    signal, sample_rate = torchaudio.load(temp_path)

                    start_sample = int(start * sample_rate)
                    end_sample = int(end * sample_rate)

                    segment_signal = signal[:, start_sample:end_sample]
                    if segment_signal.shape[0] > 1:
                        segment_signal = segment_signal.mean(dim=0, keepdim=True)

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
                        break
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

            candidates_list = []

            for candidate in enrollment_store.list_candidates():
                candidate_id = candidate["person_id"]
                candidate_embeddings = enrollment_store.get_embeddings(candidate_id)

                if not candidate_embeddings:
                    continue

                max_similarity = max(
                    cosine_similarity(sample_embedding, emb)
                    for emb in candidate_embeddings
                )

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

            candidates_list.sort(key=lambda c: c["similarity"], reverse=True)

            speaker_candidates[speaker_label] = {
                "status": "ok",
                "candidates": candidates_list,
            }

        return {
            "status": "ok",
            "speaker_candidates": speaker_candidates,
            "warnings": matching_warnings,
        }

    except Exception as e:
        logger.error("Candidate matching failed: %s", e)
        return {
            "status": "matching_failed",
            "error": str(e),
            "warnings": [
                f"Candidate matching failed: {e}. "
                "Only anonymous speaker labels are returned."
            ],
        }


def register_transcribe_routes(app: FastAPI) -> None:
    """Attach the /audio/transcriptions endpoints."""

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
        manager = app.state.manager
        embedding_extractor = app.state.embedding_extractor
        enrollment_store = app.state.enrollment_store
        threshold = app.state.similarity_threshold
        margin = app.state.ambiguity_margin
        supported_formats = app.state.supported_formats
        max_upload_bytes = app.state.max_upload_bytes

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

        suffix = Path(file.filename or "audio.wav").suffix or ".wav"
        if suffix.lower() not in supported_formats:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Unsupported audio format: {suffix}. "
                    f"Supported: {sorted(supported_formats)}"
                ),
            )

        audio_bytes = await file.read()
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Empty audio file")
        if len(audio_bytes) > max_upload_bytes:
            raise HTTPException(
                status_code=413,
                detail=(
                    f"Audio file too large: {len(audio_bytes)} bytes "
                    f"(max {max_upload_bytes})"
                ),
            )

        warnings: list[str] = []

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

                phase._unload_asr()

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

                phase._unload_align()

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

                logger.info("Phase 4: Assigning speaker labels")
                result = whisperx.assign_word_speakers(diarize_result, result)

                segments = result.get("segments", [])

                speaker_order: list[str] = []
                seen: set[str] = set()
                for seg in segments:
                    spk = seg.get("speaker", "SPEAKER_00")
                    if spk not in seen:
                        speaker_order.append(spk)
                        seen.add(spk)

                duration = None
                if segments:
                    duration = max(seg.get("end", 0) for seg in segments)

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

                identity_result = {
                    "mode": identity_mode or "off",
                    "status": "not_requested",
                }

                if identity_mode == "candidates":
                    match_result = _match_speakers_to_candidates(
                        speaker_order=speaker_order,
                        segments=segments,
                        temp_path=temp_path,
                        embedding_extractor=embedding_extractor,
                        enrollment_store=enrollment_store,
                        threshold=threshold,
                        margin=margin,
                    )

                    if match_result["status"] == "matching_failed":
                        identity_result = {
                            "mode": "candidates",
                            "status": "matching_failed",
                            "error": match_result["error"],
                            "note": "Candidate matching failed. Only anonymous speaker labels are returned.",
                        }
                    else:
                        identity_result = {
                            "mode": "candidates",
                            "status": "ok",
                            "speaker_candidates": match_result["speaker_candidates"],
                            "threshold": app.state.similarity_threshold,
                            "ambiguity_margin": app.state.ambiguity_margin,
                            "note": (
                                "Candidates are advisory only and based on voice similarity. "
                                "Do not treat as confirmed identity. Review manually before use."
                            ),
                        }

                    if match_result.get("warnings"):
                        warnings.extend(match_result["warnings"])

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
