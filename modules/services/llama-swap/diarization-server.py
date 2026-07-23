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
import stat
import tempfile
import threading
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import JSONResponse

logger = logging.getLogger("diarization-server")

# ── Limits ──────────────────────────────────────────────────────────
MAX_UPLOAD_BYTES = 50 * 1024 * 1024  # 50 MB
MAX_DURATION_SECONDS = 7200  # 2 hour (conservative bound)
SUPPORTED_FORMATS = {".wav", ".mp3", ".m4a", ".ogg", ".flac", ".webm", ".mp4"}
ENROLLMENT_DIR = Path("/var/lib/llama-swap/diarization/enrollment")
EMBEDDING_CACHE_DIR = Path("/var/lib/llama-swap/diarization/embedding-cache")
MIN_ENROLLMENT_SAMPLES = 3
# Default diarization model (community edition, no HF gated access needed).
DEFAULT_DIARIZATION_MODEL = "pyannote/speaker-diarization-community-1"


class BusyError(Exception):
    """Raised when the one-job concurrency lock cannot be acquired."""


class EmbeddingExtractor:
    """Speaker embedding extractor using SpeechBrain ECAPA-TDNN.
    
    Extracts 192-dim normalized embeddings from audio files or segments.
    Thread-safe via internal lock on model initialization.

    Device policy: auto-selects CUDA if available, otherwise CPU. Falls back
    to CPU once if CUDA initialization or forward pass fails due to device/
    runtime errors (not data errors). MKLDNN is disabled only on CPU path to
    comply with systemd MemoryDenyWriteExecute=yes.

    The model ``speechbrain/spkrec-ecapa-voxceleb`` is public on Hugging
    Face and does not require authentication.  No HF token is passed to
    ``from_hparams`` — SpeechBrain 1.1's ``Pretrained.__init__`` does not
    accept a ``token`` keyword argument.
    """
    
    def __init__(self):
        self._model = None
        self._lock = threading.Lock()
        self._model_id = "speechbrain/spkrec-ecapa-voxceleb"
        self._device = None  # Resolved at model load time
        self._cuda_fallback_used = False  # Track if we've already fallen back
    
    def _resolve_device(self):
        """Resolve device: CUDA if available, otherwise CPU."""
        import torch
        if torch.cuda.is_available():
            return "cuda"
        return "cpu"
    
    def _ensure_model(self):
        """Load the embedding model if not already loaded.
        
        Attempts CUDA first if available. On device/runtime errors during
        initialization, falls back to CPU once. MKLDNN is disabled only
        on CPU path to comply with systemd MemoryDenyWriteExecute=yes.
        """
        if self._model is not None:
            return
        
        with self._lock:
            # Double-check after acquiring lock
            if self._model is not None:
                return
            
            import torch
            # If we've already fallen back from CUDA, go straight to CPU
            if self._cuda_fallback_used:
                target_device = "cpu"
            else:
                target_device = self._resolve_device()
            
            # Try loading on target device, fallback to CPU on device errors
            for attempt_device in [target_device, "cpu"] if target_device == "cuda" else ["cpu"]:
                try:
                    # Disable MKLDNN only on CPU path
                    if attempt_device == "cpu":
                        import torch.backends.mkldnn as _mkldnn
                        _mkldnn.enabled = False
                    
                    from speechbrain.inference.speaker import EncoderClassifier
                    
                    logger.info(
                        "Loading speaker embedding model on %s%s",
                        attempt_device,
                        " (mkldnn disabled for systemd MemoryDenyWriteExecute)" if attempt_device == "cpu" else "",
                    )
                    t0 = time.monotonic()
                    # The model is public; no token is needed.  SpeechBrain
                    # 1.1 does not accept ``token=`` at from_hparams, so we
                    # never pass one.
                    self._model = EncoderClassifier.from_hparams(
                        source=self._model_id,
                        run_opts={"device": attempt_device},
                    )
                    self._device = attempt_device
                    logger.info(
                        "Speaker embedding model loaded on %s in %.1fs",
                        attempt_device,
                        time.monotonic() - t0,
                    )
                    return  # Success
                except (RuntimeError, AssertionError) as e:
                    # Device/runtime errors: CUDA OOM, driver issues, etc.
                    err_str = str(e).lower()
                    is_device_error = any(kw in err_str for kw in [
                        "cuda", "out of memory", "device", "driver", "runtime",
                    ])
                    
                    if is_device_error and attempt_device == "cuda" and not self._cuda_fallback_used:
                        logger.warning(
                            "CUDA embedding model initialization failed: %s. "
                            "Falling back to CPU.",
                            e,
                        )
                        # Clean up CUDA allocation if any
                        if torch.cuda.is_available():
                            try:
                                torch.cuda.empty_cache()
                            except Exception:
                                pass
                        self._cuda_fallback_used = True
                        continue  # Try CPU
                    else:
                        logger.error("Failed to load speaker embedding model on %s: %s", attempt_device, e)
                        raise RuntimeError(
                            f"Speaker embedding model initialization failed on {attempt_device}: {e}"
                        ) from e
                except Exception as e:
                    # Non-device errors (e.g., network, model corruption) — don't fallback
                    logger.error("Failed to load speaker embedding model on %s: %s", attempt_device, e)
                    raise RuntimeError(
                        f"Speaker embedding model initialization failed on {attempt_device}: {e}"
                    ) from e
    
    def extract_embedding(self, audio_path: str) -> np.ndarray:
        """Extract a speaker embedding from an audio file.
        
        Args:
            audio_path: Path to audio file (any format supported by torchaudio)
            
        Returns:
            1D numpy array of shape (192,) containing the embedding
            
        Raises:
            RuntimeError: If model not loaded or extraction fails
        """
        self._ensure_model()
        
        try:
            import torchaudio
            
            # Load audio and resample to 16kHz mono
            signal, sample_rate = torchaudio.load(audio_path)
            
            # Convert to mono if stereo
            if signal.shape[0] > 1:
                signal = signal.mean(dim=0, keepdim=True)
            
            # Resample to 16kHz if needed
            if sample_rate != 16000:
                resampler = torchaudio.transforms.Resample(
                    orig_freq=sample_rate,
                    new_freq=16000,
                )
                signal = resampler(signal)
                sample_rate = 16000
            
            return self._encode_waveform(signal)
            
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
            RuntimeError: If extraction fails or segment is too short
        """
        self._ensure_model()
        
        try:
            import torchaudio
            
            signal, sample_rate = torchaudio.load(audio_path)
            
            # Convert to mono
            if signal.shape[0] > 1:
                signal = signal.mean(dim=0, keepdim=True)
            
            # Resample to 16kHz
            if sample_rate != 16000:
                resampler = torchaudio.transforms.Resample(
                    orig_freq=sample_rate,
                    new_freq=16000,
                )
                signal = resampler(signal)
                sample_rate = 16000
            
            # Slice segment
            start_sample = int(start_sec * sample_rate)
            end_sample = int(end_sec * sample_rate)
            segment = signal[:, start_sample:end_sample]
            
            # Require minimum duration (0.3s) for stable embedding
            if segment.shape[1] < int(0.3 * sample_rate):
                raise RuntimeError(
                    f"Segment too short: {end_sec - start_sec:.2f}s < 0.3s"
                )
            
            return self._encode_waveform(segment)
            
        except RuntimeError as e:
            err_str = str(e).lower()
            is_short_segment = "too short" in err_str or "segment too short" in err_str
            if is_short_segment:
                # Short segments are normal exclusions, not fatal errors
                logger.warning(
                    "Excluding short segment %s [%.2f-%.2f]: %s",
                    audio_path, start_sec, end_sec, e,
                )
            else:
                logger.error(
                    "Failed to extract embedding from %s [%.2f-%.2f]: %s",
                    audio_path, start_sec, end_sec, e,
                )
            raise RuntimeError(f"Segment embedding extraction failed: {e}") from e
        except Exception as e:
            logger.error(
                "Failed to extract embedding from %s [%.2f-%.2f]: %s",
                audio_path, start_sec, end_sec, e,
            )
            raise RuntimeError(f"Segment embedding extraction failed: {e}") from e
    
    def _encode_waveform(self, signal) -> np.ndarray:
        """Encode a waveform tensor to a normalized embedding.
        
        If CUDA forward pass fails due to device/runtime error and we haven't
        already fallen back, re-initialize on CPU and retry once. Data errors
        (e.g., bad audio) are not retried.
        """
        import torch
        
        with threading.Lock():
            try:
                embedding = self._model.encode_batch(signal)
            except (RuntimeError, AssertionError) as e:
                err_str = str(e).lower()
                is_device_error = any(kw in err_str for kw in [
                    "cuda", "out of memory", "device", "driver", "runtime",
                ])
                
                if (
                    is_device_error
                    and self._device == "cuda"
                    and not self._cuda_fallback_used
                ):
                    logger.warning(
                        "CUDA embedding forward failed: %s. "
                        "Falling back to CPU and retrying.",
                        e,
                    )
                    # Clean up CUDA allocation
                    if torch.cuda.is_available():
                        try:
                            torch.cuda.empty_cache()
                        except Exception:
                            pass
                    
                    # Clear model and re-initialize on CPU
                    self._model = None
                    self._cuda_fallback_used = True
                    self._ensure_model()  # Will load on CPU
                    
                    # Retry on CPU
                    embedding = self._model.encode_batch(signal)
                else:
                    raise
        
        embedding_np = embedding.squeeze().cpu().numpy()
        norm = np.linalg.norm(embedding_np)
        if norm > 0:
            embedding_np = embedding_np / norm
        return embedding_np


class EnrollmentStore:
    """Persistent enrollment storage with atomic writes and owner-only permissions.
    
    Directory structure:
        <enrollment_dir>/<person_id>/
            metadata.json  - person metadata and sample count
            embeddings.json - list of normalized speaker embeddings
    """
    
    def __init__(self, enrollment_dir: Path):
        self.enrollment_dir = enrollment_dir
        self.enrollment_dir.mkdir(parents=True, exist_ok=True)
        # Set directory permissions to owner-only
        os.chmod(self.enrollment_dir, stat.S_IRWXU)
    
    def _person_dir(self, person_id: str) -> Path:
        """Get the directory for a person, validating person_id format."""
        # Validate person_id to prevent path traversal
        if not person_id or "/" in person_id or ".." in person_id:
            raise ValueError(f"Invalid person_id: {person_id}")
        return self.enrollment_dir / person_id
    
    def _atomic_write(self, path: Path, data: dict):
        """Write JSON data atomically with owner-only permissions."""
        # Write to temp file in same directory
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                dir=path.parent,
                delete=False,
                suffix=".tmp",
            ) as tmp:
                json.dump(data, tmp, indent=2)
                temp_path = tmp.name
            
            # Set owner-only permissions before moving
            os.chmod(temp_path, stat.S_IRUSR | stat.S_IWUSR)
            
            # Atomic rename
            os.replace(temp_path, path)
        except Exception:
            # Clean up temp file on failure
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)
            raise
    
    def initialize_enrollment(
        self,
        person_id: str,
        display_name: str,
        consent_granted: bool,
    ) -> dict:
        """Initialize a new enrollment record.
        
        Args:
            person_id: Unique person identifier
            display_name: Human-readable name
            consent_granted: Must be True to proceed
            
        Returns:
            Metadata dict
            
        Raises:
            ValueError: If consent not granted or person_id invalid
            RuntimeError: If enrollment already exists
        """
        if not consent_granted:
            raise ValueError("Consent must be granted to enroll")
        
        person_dir = self._person_dir(person_id)
        if person_dir.exists():
            raise RuntimeError(f"Enrollment already exists for {person_id}")
        
        person_dir.mkdir(parents=True, exist_ok=True)
        os.chmod(person_dir, stat.S_IRWXU)
        
        metadata = {
            "person_id": person_id,
            "display_name": display_name,
            "consent_granted": True,
            "consent_timestamp": datetime.now(timezone.utc).isoformat(),
            "samples_count": 0,
            "candidate_eligible": False,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        
        self._atomic_write(person_dir / "metadata.json", metadata)
        self._atomic_write(person_dir / "embeddings.json", {"embeddings": []})
        
        return metadata
    
    def add_sample(self, person_id: str, embedding: np.ndarray) -> dict:
        """Add a speaker embedding sample to an enrollment.
        
        Args:
            person_id: Person identifier
            embedding: Normalized speaker embedding (1D numpy array)
            
        Returns:
            Updated metadata dict
            
        Raises:
            RuntimeError: If enrollment doesn't exist
        """
        person_dir = self._person_dir(person_id)
        if not person_dir.exists():
            raise RuntimeError(f"Enrollment not found for {person_id}")
        
        # Load existing embeddings
        embeddings_path = person_dir / "embeddings.json"
        with open(embeddings_path) as f:
            data = json.load(f)
        
        # Add new embedding as list
        data["embeddings"].append(embedding.tolist())
        
        # Write back atomically
        self._atomic_write(embeddings_path, data)
        
        # Update metadata
        metadata_path = person_dir / "metadata.json"
        with open(metadata_path) as f:
            metadata = json.load(f)
        
        metadata["samples_count"] = len(data["embeddings"])
        metadata["candidate_eligible"] = metadata["samples_count"] >= MIN_ENROLLMENT_SAMPLES
        metadata["updated_at"] = datetime.now(timezone.utc).isoformat()
        
        self._atomic_write(metadata_path, metadata)
        
        return metadata
    
    def get_metadata(self, person_id: str) -> dict | None:
        """Get metadata for a person, or None if not found."""
        person_dir = self._person_dir(person_id)
        metadata_path = person_dir / "metadata.json"
        if not metadata_path.exists():
            return None
        with open(metadata_path) as f:
            return json.load(f)
    
    def get_embeddings(self, person_id: str) -> list[np.ndarray] | None:
        """Get all embeddings for a person, or None if not found."""
        person_dir = self._person_dir(person_id)
        embeddings_path = person_dir / "embeddings.json"
        if not embeddings_path.exists():
            return None
        with open(embeddings_path) as f:
            data = json.load(f)
        return [np.array(e) for e in data["embeddings"]]
    
    def list_candidates(self) -> list[dict]:
        """List all persons eligible for candidate matching."""
        candidates = []
        if not self.enrollment_dir.exists():
            return candidates
        
        for person_dir in sorted(self.enrollment_dir.iterdir()):
            if not person_dir.is_dir():
                continue
            metadata_path = person_dir / "metadata.json"
            if metadata_path.exists():
                with open(metadata_path) as f:
                    metadata = json.load(f)
                if metadata.get("candidate_eligible"):
                    candidates.append({
                        "person_id": metadata["person_id"],
                        "display_name": metadata["display_name"],
                        "samples_count": metadata["samples_count"],
                    })
        
        return candidates
    
    def list_persons(self) -> list[dict]:
        """List all enrolled persons with full metadata for inventory."""
        persons = []
        if not self.enrollment_dir.exists():
            return persons
        
        for person_dir in sorted(self.enrollment_dir.iterdir()):
            if not person_dir.is_dir():
                continue
            metadata_path = person_dir / "metadata.json"
            if metadata_path.exists():
                try:
                    with open(metadata_path) as f:
                        metadata = json.load(f)
                    persons.append(metadata)
                except Exception as e:
                    logger.warning("Failed to read metadata for %s: %s", person_dir.name, e)
        
        return persons


class EmbeddingCache:
    """Revisioned cache for per-recording speaker embeddings.
    
    Storage layout (adjacent to enrollment, owner-only):
        <cache_dir>/<cache_id>/
            manifest.json    - revision inputs (audio_sha, transcript_sha,
                               model_id, segment_set_hash, built_at)
            prototypes.json  - per-label prototype embeddings + supporting
                               per-segment embeddings (no raw audio retained)
    
    Cache key = sha256(audio_sha + transcript_sha + model_id + segment_set_hash).
    Any change to inputs invalidates the cache (stale detection).
    
    Biometric data: embeddings are protected (0600), never leave server storage,
    never enter repo output, and no raw audio is retained.
    """
    
    SCHEMA_VERSION = 1
    
    def __init__(self, cache_dir: Path, embedding_model_id: str):
        self.cache_dir = cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        os.chmod(self.cache_dir, stat.S_IRWXU)
        self.embedding_model_id = embedding_model_id
    
    @staticmethod
    def _sha256_bytes(data: bytes) -> str:
        import hashlib
        return hashlib.sha256(data).hexdigest()
    
    @staticmethod
    def _sha256_file(path: Path) -> str:
        import hashlib
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest()
    
    @staticmethod
    def _segment_set_hash(segments: list[dict]) -> str:
        """Hash the canonical set of diarized segments (label, start, end).
        
        Sorted for order-independence. Precision truncated to 3 decimals
        to avoid floating-point drift across JSON round-trips.
        """
        normalized = sorted(
            (
                s.get("speaker", ""),
                round(float(s.get("start", 0)), 3),
                round(float(s.get("end", 0)), 3),
            )
            for s in segments
        )
        import hashlib
        return hashlib.sha256(json.dumps(normalized).encode("utf-8")).hexdigest()
    
    def compute_cache_id(
        self,
        audio_sha: str,
        transcript_sha: str,
        segment_set_hash: str,
    ) -> str:
        """Deterministic cache ID from revision inputs."""
        import hashlib
        blob = (
            f"v{self.SCHEMA_VERSION}|"
            f"{self.embedding_model_id}|"
            f"{audio_sha}|{transcript_sha}|{segment_set_hash}"
        )
        return hashlib.sha256(blob.encode("utf-8")).hexdigest()
    
    def _cache_dir_for(self, cache_id: str) -> Path:
        # Validate cache_id format (hex only) to prevent traversal
        if not cache_id or len(cache_id) != 64 or not all(c in "0123456789abcdef" for c in cache_id):
            raise ValueError(f"Invalid cache_id: {cache_id}")
        return self.cache_dir / cache_id
    
    def _atomic_write(self, path: Path, data: dict):
        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", dir=path.parent, delete=False, suffix=".tmp",
            ) as tmp:
                json.dump(data, tmp, indent=2)
                temp_path = tmp.name
            os.chmod(temp_path, stat.S_IRUSR | stat.S_IWUSR)
            os.replace(temp_path, path)
        except Exception:
            if temp_path and os.path.exists(temp_path):
                os.unlink(temp_path)
            raise
    
    def lookup(
        self,
        audio_sha: str,
        transcript_sha: str,
        segment_set_hash: str,
    ) -> dict:
        """Check cache status without building.
        
        Returns dict with 'status' in {hit, stale, missing} and metadata.
        """
        cache_id = self.compute_cache_id(audio_sha, transcript_sha, segment_set_hash)
        cdir = self._cache_dir_for(cache_id)
        manifest_path = cdir / "manifest.json"
        
        if not manifest_path.exists():
            # Check if a different-revision cache exists for this recording
            # by scanning for any manifest referencing these inputs
            return {"status": "missing", "cache_id": cache_id}
        
        try:
            with open(manifest_path) as f:
                manifest = json.load(f)
        except Exception:
            return {"status": "missing", "cache_id": cache_id}
        
        # Verify revision inputs match
        if (
            manifest.get("audio_sha") == audio_sha
            and manifest.get("transcript_sha") == transcript_sha
            and manifest.get("segment_set_hash") == segment_set_hash
            and manifest.get("embedding_model_id") == self.embedding_model_id
            and manifest.get("schema_version") == self.SCHEMA_VERSION
        ):
            return {"status": "hit", "cache_id": cache_id, "manifest": manifest}
        
        return {"status": "stale", "cache_id": cache_id, "existing_manifest": manifest}
    
    def store(
        self,
        audio_sha: str,
        transcript_sha: str,
        segment_set_hash: str,
        prototypes: dict,
        segment_embeddings: list,
        recording_name: str,
        exclusion_metadata: dict | None = None,
    ) -> dict:
        """Store a cache entry atomically.
        
        Args:
            prototypes: {label: {"embedding": [...], "segment_count": N, "total_duration": S}}
            segment_embeddings: list of {label, start, end, embedding, duration}
            recording_name: for audit trail only
            exclusion_metadata: optional {excluded_segment_count, excluded_segments,
                excluded_label_count, excluded_labels} for audit trail
        
        Returns:
            {"cache_id": ..., "status": "built"|"hit", ...}
        """
        cache_id = self.compute_cache_id(audio_sha, transcript_sha, segment_set_hash)
        cdir = self._cache_dir_for(cache_id)
        manifest_path = cdir / "manifest.json"
        
        # Idempotent: if already stored with matching revision, return hit
        if manifest_path.exists():
            try:
                with open(manifest_path) as f:
                    existing = json.load(f)
                if (
                    existing.get("audio_sha") == audio_sha
                    and existing.get("transcript_sha") == transcript_sha
                    and existing.get("segment_set_hash") == segment_set_hash
                ):
                    return {"status": "hit", "cache_id": cache_id, "manifest": existing}
            except Exception:
                pass
        
        cdir.mkdir(parents=True, exist_ok=True)
        os.chmod(cdir, stat.S_IRWXU)
        
        manifest = {
            "schema_version": self.SCHEMA_VERSION,
            "cache_id": cache_id,
            "embedding_model_id": self.embedding_model_id,
            "audio_sha": audio_sha,
            "transcript_sha": transcript_sha,
            "segment_set_hash": segment_set_hash,
            "recording_name": recording_name,
            "built_at": datetime.now(timezone.utc).isoformat(),
            "label_count": len(prototypes),
            "segment_count": len(segment_embeddings),
        }
        if exclusion_metadata:
            manifest["excluded_segment_count"] = exclusion_metadata.get("excluded_segment_count", 0)
            manifest["excluded_label_count"] = exclusion_metadata.get("excluded_label_count", 0)
            manifest["excluded_labels"] = exclusion_metadata.get("excluded_labels", [])
        
        prototypes_doc = {
            "schema_version": self.SCHEMA_VERSION,
            "prototypes": prototypes,
            "segments": segment_embeddings,
        }
        
        self._atomic_write(manifest_path, manifest)
        self._atomic_write(cdir / "prototypes.json", prototypes_doc)
        
        return {"status": "built", "cache_id": cache_id, "manifest": manifest}
    
    def load(self, cache_id: str) -> dict | None:
        """Load prototypes and segments for a cache entry, or None if missing."""
        cdir = self._cache_dir_for(cache_id)
        manifest_path = cdir / "manifest.json"
        prototypes_path = cdir / "prototypes.json"
        if not manifest_path.exists() or not prototypes_path.exists():
            return None
        try:
            with open(manifest_path) as f:
                manifest = json.load(f)
            with open(prototypes_path) as f:
                prototypes = json.load(f)
            return {"manifest": manifest, "prototypes": prototypes}
        except Exception as e:
            logger.warning("Failed to load cache %s: %s", cache_id, e)
            return None


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """Compute cosine similarity between two normalized vectors.
    
    Assumes inputs are already normalized to unit length.
    Returns value in [-1, 1], where 1 means identical.
    """
    # For normalized vectors, cosine similarity is just dot product
    return float(np.dot(a, b))


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


def create_app(args: argparse.Namespace) -> FastAPI:
    manager = ModelManager(args)
    enrollment_dir = Path(args.enrollment_dir)
    enrollment_store = EnrollmentStore(enrollment_dir)
    # The embedding model is public; no HF token is needed.
    embedding_extractor = EmbeddingExtractor()
    # Embedding cache lives adjacent to enrollment, same owner-only protection.
    cache_dir = enrollment_dir.parent / "embedding-cache"
    embedding_cache = EmbeddingCache(cache_dir, embedding_extractor._model_id)
    
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
        
        Extracts speaker embedding (auto CUDA/CPU) and stores it. Does not retain
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
            
            # Extract embedding (auto CUDA/CPU, lazy-loaded)
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
            
            # Check cache status
            lookup = embedding_cache.lookup(audio_sha, transcript_sha, segment_set_hash)
            if lookup["status"] == "hit":
                return {
                    "status": "hit",
                    "cache_id": lookup["cache_id"],
                    "recording_name": recording_name,
                    "label_count": lookup["manifest"].get("label_count", 0),
                    "segment_count": lookup["manifest"].get("segment_count", 0),
                }
            
            # Extract embeddings per segment
            segment_embeddings = []
            label_embeddings = {}  # label -> list of embeddings
            excluded_segments = []  # track failures with reasons
            label_failure_counts = {}  # label -> count of failed segments
            
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
                
                try:
                    emb = embedding_extractor.extract_embedding_from_segment(
                        temp_audio, start, end
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
                except Exception as e:
                    # Determine specific reason
                    reason = "extraction_failed"
                    err_str = str(e).lower()
                    if "too short" in err_str or "segment too short" in err_str:
                        reason = "segment_too_short"
                    
                    excluded_segments.append({
                        "label": label,
                        "start": start,
                        "end": end,
                        "reason": reason,
                        "error": str(e),
                    })
                    label_failure_counts[label] = label_failure_counts.get(label, 0) + 1
                    logger.warning(
                        "Failed to extract embedding for %s [%.2f-%.2f]: %s",
                        recording_name, start, end, e,
                    )
            
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
