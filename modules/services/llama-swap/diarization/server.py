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

This module is the thin assembly spine: it builds the CLI parser,
constructs shared services, wires them onto ``app.state``, and
delegates endpoint definitions to the ``routes/`` subpackage.
"""

import argparse
import asyncio
import logging
from contextlib import asynccontextmanager
from pathlib import Path

import uvicorn
from fastapi import FastAPI

from .cache import EmbeddingCache
from .embeddings import EmbeddingExtractor
from .enrollment import EnrollmentStore
from .models import ModelManager
from .routes.cache import register_cache_routes
from .routes.health import register_health_routes
from .routes.identity import register_identity_routes
from .routes.transcribe import register_transcribe_routes

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
        app.state.enrollment_dir = enrollment_dir
        app.state.embedding_extractor = embedding_extractor
        app.state.embedding_cache = embedding_cache
        app.state.similarity_threshold = args.similarity_threshold
        app.state.ambiguity_margin = args.ambiguity_margin
        app.state.recording_locks = recording_locks
        app.state.supported_formats = SUPPORTED_FORMATS
        app.state.max_upload_bytes = MAX_UPLOAD_BYTES
        enrollment_dir.mkdir(parents=True, exist_ok=True)
        cache_dir.mkdir(parents=True, exist_ok=True)
        yield

    app = FastAPI(lifespan=lifespan)

    register_health_routes(app)
    register_transcribe_routes(app)
    register_identity_routes(app)
    register_cache_routes(app)

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
