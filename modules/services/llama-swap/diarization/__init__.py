"""WhisperX diarization server package.

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

from .embeddings import EmbeddingExtractor, ShortSegmentSkipped
from .enrollment import EnrollmentStore, MIN_ENROLLMENT_SAMPLES
from .cache import EmbeddingCache
from .identity import cosine_similarity
from .models import ModelManager, BusyError

__all__ = [
    "EmbeddingExtractor",
    "ShortSegmentSkipped",
    "EnrollmentStore",
    "MIN_ENROLLMENT_SAMPLES",
    "EmbeddingCache",
    "cosine_similarity",
    "ModelManager",
    "BusyError",
]
