#!/usr/bin/env python3
"""WhisperX diarization server for llama-swap.

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
import json
import logging
import os
import tempfile
import threading
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse


logger = logging.getLogger("diarization-server")

# ── Limits ──────────────────────────────────────────────────────────
MAX_UPLOAD_BYTES = 25 * 1024 * 1024  # 25 MB
MAX_DURATION_SECONDS = 3600  # 1 hour (conservative bound)
SUPPORTED_FORMATS = {".wav", ".mp3", ".m4a", ".ogg", ".flac", ".webm", ".mp4"}
ENROLLMENT_DIR = Path("/var/lib/llama-swap/diarization/enrollment")
MIN_ENROLLMENT_SAMPLES = 3
# Default diarization model (community edition, no HF gated access needed).
DEFAULT_DIARIZATION_MODEL = "pyannote/speaker-diarization-community-1"


class BusyError(Exception):
    """Raised when the one-job concurrency lock cannot be acquired."""


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
    return parser


class ModelManager:
    """GPU model lifecycle manager with phase loading.

    Only one model is resident on the GPU at a time. ASR is loaded for
    transcription, then unloaded before the diarization pipeline loads.
    A threading lock enforces one-job concurrency.
    """

    def __init__(self, args: argparse.Namespace):
        self.args = args
        self._lock = threading.Lock()
        self._asr_model = None
        self._align_model = None
        self._align_metadata = None
        self._diarize_pipeline = None
        self._hf_token = self._load_hf_token(args.hf_token_path)
        self.device = args.device
        self.model_id = args.model_id

        # Fail fast if CUDA is requested but unavailable
        import torch

        if args.device == "cuda" and not torch.cuda.is_available():
            raise RuntimeError(
                "CUDA requested but not available. "
                "Service cannot start without GPU acceleration."
            )

    def _load_hf_token(self, path: str | None) -> str | None:
        if path and os.path.exists(path):
            return Path(path).read_text().strip()
        return os.environ.get("HF_TOKEN") or os.environ.get(
            "HUGGING_FACE_HUB_TOKEN"
        )

    # ── ASR ──────────────────────────────────────────────────

    def _ensure_asr(self):
        if self._asr_model is None:
            import whisperx

            logger.info("Loading WhisperX ASR model on %s", self.device)
            t0 = time.monotonic()
            self._asr_model = whisperx.load_model(
                "medium",
                self.device,
                compute_type=self.args.compute_type,
                download_root=self.args.download_root,
                language=self.args.language,
            )
            logger.info(
                "ASR model loaded in %.1fs", time.monotonic() - t0
            )

    def _unload_asr(self):
        if self._asr_model is not None:
            del self._asr_model
            self._asr_model = None
            self._gc_cuda()
            logger.info("Unloaded ASR model")

    # ── Alignment ────────────────────────────────────────────

    def _ensure_align(self, language_code: str):
        if self._align_model is None:
            import whisperx

            logger.info("Loading alignment model for %s", language_code)
            t0 = time.monotonic()
            self._align_model, self._align_metadata = (
                whisperx.load_align_model(
                    language_code=language_code,
                    device=self.device,
                )
            )
            logger.info(
                "Alignment model loaded in %.1fs", time.monotonic() - t0
            )

    def _unload_align(self):
        if self._align_model is not None:
            del self._align_model
            del self._align_metadata
            self._align_model = None
            self._align_metadata = None
            self._gc_cuda()
            logger.info("Unloaded alignment model")

    # ── Diarization ──────────────────────────────────────────

    def _ensure_diarize(self):
        if self._diarize_pipeline is None:
            # DiarizationPipeline lives in whisperx.diarize, NOT in
            # whisperx.__init__ (whisperx 3.8.6).
            from whisperx.diarize import DiarizationPipeline

            needs_token = self._hf_token is not None
            if not needs_token:
                logger.warning(
                    "No HuggingFace token provided. Using default "
                    "community diarization model. If you switch to a "
                    "gated model, set HF_TOKEN or --hf-token-path."
                )

            logger.info("Loading diarization pipeline on %s", self.device)
            t0 = time.monotonic()
            pipeline_kwargs: dict = {
                "model_name": self.args.diarization_model,
                "device": self.device,
            }
            # Only pass token for gated models; the community model
            # works without one.  WhisperX 3.8.6 DiarizationPipeline
            # accepts ``token=``, NOT ``use_auth_token=``.
            if self._hf_token:
                pipeline_kwargs["token"] = self._hf_token
            self._diarize_pipeline = DiarizationPipeline(
                **pipeline_kwargs,
            )
            logger.info(
                "Diarization pipeline loaded in %.1fs",
                time.monotonic() - t0,
            )

    def _unload_diarize(self):
        if self._diarize_pipeline is not None:
            del self._diarize_pipeline
            self._diarize_pipeline = None
            self._gc_cuda()
            logger.info("Unloaded diarization model")

    # ── GPU housekeeping ─────────────────────────────────────

    def _gc_cuda(self):
        import torch

        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.synchronize()

    # ── Concurrency ──────────────────────────────────────────

    def acquire(self, timeout: float = 60):
        """Acquire the model lock. Returns a _ModelPhase context manager."""
        return _ModelPhase(self, timeout)


class _ModelPhase:
    """Context manager that holds the model lock and cleans up on exit.

    Delegates model lifecycle methods and attribute access to the
    underlying :class:`ModelManager` so handler code can call
    ``phase._ensure_asr()`` etc. uniformly.
    """

    def __init__(self, manager: ModelManager, timeout: float):
        self._mgr = manager
        self._acquired = False
        if not manager._lock.acquire(timeout=timeout):
            raise BusyError(
                "Another transcription job is running (concurrency limit 1). "
                "Retry after the current job completes."
            )
        self._acquired = True

    # ── Lifecycle delegation ───────────────────────────────

    def _ensure_asr(self):
        self._mgr._ensure_asr()

    def _unload_asr(self):
        self._mgr._unload_asr()

    def _ensure_align(self, language_code: str):
        self._mgr._ensure_align(language_code)

    def _unload_align(self):
        self._mgr._unload_align()

    def _ensure_diarize(self):
        self._mgr._ensure_diarize()

    def _unload_diarize(self):
        self._mgr._unload_diarize()

    # ── Model attribute proxies ────────────────────────────

    @property
    def _asr_model(self):
        return self._mgr._asr_model

    @property
    def _align_model(self):
        return self._mgr._align_model

    @property
    def _align_metadata(self):
        return self._mgr._align_metadata

    @property
    def _diarize_pipeline(self):
        return self._mgr._diarize_pipeline

    # ── Context protocol ──────────────────────────────────

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        if self._acquired:
            self._mgr._unload_asr()
            self._mgr._unload_align()
            self._mgr._unload_diarize()
            self._mgr._lock.release()


def create_app(args: argparse.Namespace) -> FastAPI:
    manager = ModelManager(args)
    enrollment_dir = Path(args.enrollment_dir)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.manager = manager
        app.state.model_id = args.model_id
        app.state.device = args.device
        enrollment_dir.mkdir(parents=True, exist_ok=True)
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
                detail=(
                    f"Model must be '{app.state.model_id}', got '{model}'"
                ),
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
            with tempfile.NamedTemporaryFile(
                delete=False, suffix=suffix
            ) as tmp:
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

                detected_language = result.get(
                    "language", language or "unknown"
                )
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
                result = whisperx.assign_word_speakers(
                    diarize_result, result
                )

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
                    duration = max(
                        seg.get("end", 0) for seg in segments
                    )

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

                full_text = " ".join(
                    s["text"] for s in output_segments
                ).strip()

                # Identity mode handling
                identity_status = "not_requested"
                if identity_mode == "candidates":
                    identity_status = "matching_unavailable"
                    warnings.append(
                        "Identity matching is not available: "
                        "cross-session speaker embedding verification "
                        "is pending. Only anonymous speaker labels are "
                        "returned."
                    )

                return JSONResponse(
                    {
                        "text": full_text,
                        "language": detected_language,
                        "duration": round(duration, 3)
                        if duration is not None
                        else None,
                        "segments": output_segments,
                        "speakers": speaker_order,
                        "identity": {
                            "mode": identity_mode or "off",
                            "status": identity_status,
                        },
                        "warnings": warnings,
                    }
                )

        finally:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)

    # ── Enrollment endpoints (disabled) ──────────────────────
    #
    # Enrollment and sample ingestion are disabled until a verified
    # embedding matcher is implemented.  Storing raw audio without a
    # matcher creates retention liability with no functional use.
    # The endpoints return 501 to signal "not implemented" while
    # preserving the API contract for future enablement.

    _ENROLLMENT_DISABLED_DETAIL = (
        "Speaker enrollment is not yet implemented. "
        "Cross-session embedding matching must be verified against "
        "the installed pyannote-audio/speechbrain versions before "
        "raw audio can be accepted. See the docs for current status."
    )

    @app.post("/v1/identity/enroll")
    async def enroll_person(
        consent: bool = Form(...),
        person_id: str = Form(...),
        display_name: str = Form(...),
    ):
        """Enrollment endpoint — returns 501 until embedding matcher exists."""
        raise HTTPException(
            status_code=501,
            detail=_ENROLLMENT_DISABLED_DETAIL,
        )

    @app.post("/v1/identity/samples")
    async def upload_sample(
        person_id: str = Form(...),
        file: UploadFile = File(...),
    ):
        """Sample upload endpoint — returns 501 until embedding matcher exists."""
        raise HTTPException(
            status_code=501,
            detail=_ENROLLMENT_DISABLED_DETAIL,
        )

    @app.get("/v1/identity/candidates")
    async def list_candidates():
        """List enrolled speakers who meet the sample threshold.

        Returns matching_unavailable status because cross-session speaker
        embedding matching has not been verified in the installed package
        versions. The candidate list is provided for manual review only.
        """
        candidates = []
        if enrollment_dir.exists():
            for person_dir in sorted(enrollment_dir.iterdir()):
                meta_path = person_dir / "metadata.json"
                if meta_path.exists():
                    meta = json.loads(meta_path.read_text())
                    if meta.get("candidate_eligible"):
                        candidates.append(
                            {
                                "person_id": meta["person_id"],
                                "display_name": meta["display_name"],
                                "samples_count": meta["samples_count"],
                            }
                        )

        return {
            "status": "matching_unavailable",
            "reason": (
                "Cross-session speaker embedding matching is not yet "
                "verified in the installed pyannote-audio/speechbrain "
                "versions. Candidate list is for manual review only."
            ),
            "candidates": candidates,
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
