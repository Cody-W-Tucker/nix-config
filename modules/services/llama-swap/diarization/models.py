"""GPU model lifecycle manager with phase loading.

Only one model is resident on the GPU at a time. ASR is loaded for
transcription, then unloaded before the diarization pipeline loads.
A threading lock enforces one-job concurrency.
"""

import argparse
import logging
import os
import threading
import time
from pathlib import Path

logger = logging.getLogger("diarization-server")


class BusyError(Exception):
    """Raised when the one-job concurrency lock cannot be acquired."""


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
        return os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")

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
            logger.info("ASR model loaded in %.1fs", time.monotonic() - t0)

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
            self._align_model, self._align_metadata = whisperx.load_align_model(
                language_code=language_code,
                device=self.device,
            )
            logger.info("Alignment model loaded in %.1fs", time.monotonic() - t0)

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
