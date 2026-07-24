"""Speaker embedding extraction using SpeechBrain ECAPA-TDNN.

Extracts 192-dim normalized embeddings from audio files or segments.
Thread-safe via internal lock on model initialization.

Device policy: CUDA-only. Both preprocessing (resampling) and inference
run on the selected CUDA device. If CUDA is unavailable or model
load/inference fails, a clear error is raised — no CPU fallback.

The model ``speechbrain/spkrec-ecapa-voxceleb`` is public on Hugging
Face and does not require authentication.  No HF token is passed to
``from_hparams`` — SpeechBrain 1.1's ``Pretrained.__init__`` does not
accept a ``token`` keyword argument.
"""

import logging
import threading
import time

import numpy as np

logger = logging.getLogger("diarization-server")


class ShortSegmentSkipped(Exception):
    """Raised when a segment is too short for stable embedding extraction.

    This is an expected skip, not a failure. Callers distinguish this from
    genuine CUDA/audio errors and count it separately. Never logged at
    error level or wrapped as a RuntimeError.
    """


class EmbeddingExtractor:
    """Speaker embedding extractor using SpeechBrain ECAPA-TDNN.

    Extracts 192-dim normalized embeddings from audio files or segments.
    Thread-safe via internal lock on model initialization.

    Device policy: CUDA-only. Both preprocessing (resampling) and inference
    run on the selected CUDA device. If CUDA is unavailable or model
    load/inference fails, a clear error is raised — no CPU fallback.

    The model ``speechbrain/spkrec-ecapa-voxceleb`` is public on Hugging
    Face and does not require authentication.  No HF token is passed to
    ``from_hparams`` — SpeechBrain 1.1's ``Pretrained.__init__`` does not
    accept a ``token`` keyword argument.
    """

    # Minimum segment duration for stable embedding extraction (seconds).
    # Segments shorter than this are excluded before any GPU work.
    MIN_SEGMENT_DURATION = 0.3

    def __init__(self, device_index: int = 0):
        self._model = None
        self._lock = threading.Lock()
        # Instance-level GPU critical section: serializes CUDA resample + forward
        # across threads. CPU decode/slicing happens outside this lock so multiple
        # recordings can overlap CPU work while GPU work is serialized.
        self._gpu_lock = threading.Lock()
        self._model_id = "speechbrain/spkrec-ecapa-voxceleb"
        self._device = None  # Resolved at model load time (e.g. "cuda:0")
        self._device_index = device_index

    def _resolve_device(self) -> str:
        """Resolve device: indexed CUDA (e.g. 'cuda:0'). Raises if unavailable.

        SpeechBrain's device parser requires the 'cuda:N' format — bare 'cuda'
        causes a parse error ('not enough values to unpack') and silent fallback
        that leads to forward-pass failures.
        """
        import torch
        if not torch.cuda.is_available():
            raise RuntimeError(
                "CUDA is required for embedding extraction but is not available. "
                "Ensure a CUDA-capable GPU and driver are present. "
                "CPU fallback is not supported."
            )
        return f"cuda:{self._device_index}"

    def _ensure_model(self):
        """Load the embedding model on CUDA if not already loaded.

        Raises RuntimeError with actionable message if CUDA unavailable or
        model load fails. No CPU fallback.
        """
        if self._model is not None:
            return

        with self._lock:
            # Double-check after acquiring lock
            if self._model is not None:
                return

            import torch
            target_device = self._resolve_device()

            logger.info(
                "Speaker embedding model: target device=%s (CUDA available=%s)",
                target_device, torch.cuda.is_available(),
            )

            try:
                from speechbrain.inference.speaker import EncoderClassifier

                logger.info("Loading speaker embedding model on %s", target_device)
                t0 = time.monotonic()
                # The model is public; no token is needed.  SpeechBrain
                # 1.1 does not accept ``token=`` at from_hparams, so we
                # never pass one.
                self._model = EncoderClassifier.from_hparams(
                    source=self._model_id,
                    run_opts={"device": target_device},
                )
                self._device = target_device
                logger.info(
                    "Speaker embedding model loaded on %s in %.1fs",
                    target_device,
                    time.monotonic() - t0,
                )
            except Exception as e:
                logger.error(
                    "Failed to load speaker embedding model on %s: %s",
                    target_device, e,
                )
                raise RuntimeError(
                    f"Speaker embedding model initialization failed on {target_device}: {e}. "
                    f"CUDA is required; CPU fallback is not supported."
                ) from e

    def _move_and_resample(self, signal, sample_rate: int, target_rate: int = 16000):
        """Move signal to CUDA device and resample if needed.

        Returns (signal, sample_rate) on the CUDA device.
        Resampling runs on CUDA — never on CPU.

        NOTE: Caller must hold self._gpu_lock when calling this method,
        as it performs CUDA operations.
        """
        import torchaudio

        # Move to CUDA device before any GPU work
        signal = signal.to(self._device)

        if sample_rate != target_rate:
            resampler = torchaudio.transforms.Resample(
                orig_freq=sample_rate,
                new_freq=target_rate,
            ).to(self._device)
            signal = resampler(signal)
            sample_rate = target_rate

        return signal, sample_rate

    def _gpu_resample_and_encode(self, segment, sample_rate: int) -> np.ndarray:
        """Resample on CUDA and encode to embedding. Holds GPU lock for entire operation.

        This is the GPU critical section: both resampling and the SpeechBrain
        forward pass happen under self._gpu_lock. CPU work (decode, slicing,
        duration checks) happens outside this lock so multiple recordings can
        overlap their CPU-bound decode work.

        Args:
            segment: CPU tensor, shape (1, N) or (N,)
            sample_rate: Sample rate of the segment

        Returns:
            1D numpy array of shape (192,) containing the normalized embedding
        """
        with self._gpu_lock:
            segment, _ = self._move_and_resample(segment, sample_rate)
            return self._encode_waveform(segment)

    def extract_embedding_from_waveform(
        self,
        signal,
        sample_rate: int,
        start_sec: float | None = None,
        end_sec: float | None = None,
    ) -> np.ndarray:
        """Extract a speaker embedding from a pre-decoded waveform.

        This is the core embedding method used by cache build. Audio is decoded
        ONCE by the caller, then segments are extracted by sample indices.
        CPU work (mono conversion, slicing, duration check) happens on CPU.
        GPU work (resample + forward) is serialized via self._gpu_lock.

        Args:
            signal: CPU tensor from torchaudio.load, shape (channels, samples)
            sample_rate: Sample rate of the signal
            start_sec: Optional start time in seconds (None = from beginning)
            end_sec: Optional end time in seconds (None = to end)

        Returns:
            1D numpy array of shape (192,) containing the normalized embedding

        Raises:
            ShortSegmentSkipped: If segment is too short (< MIN_SEGMENT_DURATION)
            RuntimeError: If model not loaded, extraction fails, or CUDA unavailable
        """
        self._ensure_model()

        try:
            import torch

            # Ensure mono on CPU
            if signal.dim() == 1:
                signal = signal.unsqueeze(0)
            elif signal.shape[0] > 1:
                signal = signal.mean(dim=0, keepdim=True)

            # Slice segment on CPU if time range provided
            if start_sec is not None and end_sec is not None:
                start_sample = int(start_sec * sample_rate)
                end_sample = int(end_sec * sample_rate)
                segment = signal[:, start_sample:end_sample]
                segment_duration = (end_sample - start_sample) / sample_rate
            else:
                segment = signal
                segment_duration = signal.shape[1] / sample_rate

            # Duration check BEFORE GPU work — short segments cannot produce
            # stable embeddings and must be excluded early.
            if segment_duration < self.MIN_SEGMENT_DURATION:
                raise ShortSegmentSkipped(
                    f"Segment too short: {segment_duration:.2f}s < {self.MIN_SEGMENT_DURATION}s"
                )

            # GPU work: resample on CUDA + encode, serialized via _gpu_lock
            return self._gpu_resample_and_encode(segment, sample_rate)

        except ShortSegmentSkipped:
            raise
        except RuntimeError:
            raise
        except Exception as e:
            logger.error("Failed to extract embedding from waveform: %s", e)
            raise RuntimeError(f"Waveform embedding extraction failed: {e}") from e

    def extract_embedding(self, audio_path: str) -> np.ndarray:
        """Extract a speaker embedding from an audio file.

        Args:
            audio_path: Path to audio file (any format supported by torchaudio)

        Returns:
            1D numpy array of shape (192,) containing the embedding

        Raises:
            RuntimeError: If model not loaded, extraction fails, audio too short,
                or CUDA unavailable/failed. No CPU fallback.
        """
        self._ensure_model()

        try:
            import torchaudio

            # Load audio (CPU decode — torchaudio.load always returns CPU tensors)
            signal, sample_rate = torchaudio.load(audio_path)

            # Convert to mono if stereo
            if signal.shape[0] > 1:
                signal = signal.mean(dim=0, keepdim=True)

            # Delegate to waveform method for duration check + GPU work
            return self.extract_embedding_from_waveform(signal, sample_rate)

        except ShortSegmentSkipped:
            # Expected skip — propagate without wrapping or error-level log.
            raise
        except RuntimeError:
            raise
        except Exception as e:
            logger.error("Failed to extract embedding from %s: %s", audio_path, e)
            raise RuntimeError(f"Embedding extraction failed: {e}") from e

    def extract_embedding_from_segment(
        self,
        audio_path: str,
        start_sec: float,
        end_sec: float,
    ) -> np.ndarray:
        """Extract a speaker embedding from a time slice of an audio file.

        Args:
            audio_path: Path to audio file
            start_sec: Start time in seconds
            end_sec: End time in seconds

        Returns:
            1D numpy array of shape (192,) containing the normalized embedding

        Raises:
            RuntimeError: If extraction fails, segment too short, or CUDA
                unavailable/failed. No CPU fallback.
        """
        self._ensure_model()

        try:
            import torchaudio

            logger.debug(
                "DIAGNOSTIC: extract_embedding_from_segment start: audio=%s, range=[%.2f-%.2f], device=%s",
                audio_path, start_sec, end_sec, self._device,
            )

            # Load audio (CPU decode)
            signal, sample_rate = torchaudio.load(audio_path)

            logger.debug(
                "DIAGNOSTIC: torchaudio.load success: signal.shape=%s, sample_rate=%s",
                signal.shape, sample_rate,
            )

            # Convert to mono
            if signal.shape[0] > 1:
                signal = signal.mean(dim=0, keepdim=True)

            # Delegate to waveform method for slicing, duration check, and GPU work
            return self.extract_embedding_from_waveform(signal, sample_rate, start_sec, end_sec)

        except ShortSegmentSkipped as e:
            # Expected skip — log once at info level, propagate without wrapping.
            logger.info(
                "Skipping short segment %s [%.2f-%.2f]: %s",
                audio_path, start_sec, end_sec, e,
            )
            raise
        except RuntimeError as e:
            logger.exception(
                "DIAGNOSTIC: Full traceback for embedding extraction failure from %s [%.2f-%.2f]",
                audio_path, start_sec, end_sec,
            )
            logger.error(
                "Failed to extract embedding from %s [%.2f-%.2f]: %s",
                audio_path, start_sec, end_sec, e,
            )
            raise RuntimeError(f"Segment embedding extraction failed: {e}") from e
        except Exception as e:
            logger.exception(
                "DIAGNOSTIC: Full traceback for non-RuntimeError embedding extraction failure from %s [%.2f-%.2f]",
                audio_path, start_sec, end_sec,
            )
            logger.error(
                "Failed to extract embedding from %s [%.2f-%.2f]: %s",
                audio_path, start_sec, end_sec, e,
            )
            raise RuntimeError(f"Segment embedding extraction failed: {e}") from e

    def _encode_waveform(self, signal) -> np.ndarray:
        """Encode a waveform tensor to a normalized embedding.

        Signal must already be on the model's CUDA device. Raises on failure
        with no CPU fallback.

        NOTE: Caller must hold self._gpu_lock when calling this method,
        as it performs CUDA operations.
        """
        import torch

        # Ensure signal is on the same device as the model.
        model_device = next(self._model.parameters()).device
        if signal.device != model_device:
            signal = signal.to(model_device)

        logger.debug(
            "DIAGNOSTIC _encode_waveform: signal.shape=%s, signal.device=%s, model.device=%s",
            signal.shape, signal.device, model_device,
        )

        try:
            logger.debug("DIAGNOSTIC: calling model.encode_batch...")
            embedding = self._model.encode_batch(signal)
            logger.debug(
                "DIAGNOSTIC: encode_batch success: embedding.shape=%s",
                embedding.shape if hasattr(embedding, 'shape') else type(embedding),
            )
        except Exception as e:
            logger.exception(
                "DIAGNOSTIC: encode_batch failed: error=%s, device=%s",
                e, self._device,
            )
            raise RuntimeError(
                f"CUDA embedding forward failed on {self._device}: {e}. "
                f"CUDA is required; CPU fallback is not supported."
            ) from e

        embedding_np = embedding.squeeze().cpu().numpy()
        norm = np.linalg.norm(embedding_np)
        if norm > 0:
            embedding_np = embedding_np / norm
        return embedding_np
