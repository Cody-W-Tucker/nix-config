#!/usr/bin/env python3
"""Compatibility launcher for the diarization server.

This thin shim re-exports everything from the ``diarization`` package so
that existing test imports (``importlib.util.spec_from_file_location``
targeting this file) continue to resolve.  All substantive implementation
lives under ``diarization/``.

The Nix launch wiring invokes ``python -m diarization.server`` directly
and does not go through this file.
"""

# Import only the data/model classes that tests actually need.
# These modules don't import uvicorn/fastapi at the top level, so tests
# can load them without mocking the full web stack.
from diarization import (  # noqa: F401
    BusyError,
    EmbeddingCache,
    EmbeddingExtractor,
    EnrollmentStore,
    MIN_ENROLLMENT_SAMPLES,
    ModelManager,
    ShortSegmentSkipped,
    cosine_similarity,
)

# Server-specific names (routes, CLI, main) are imported lazily to avoid
# pulling in uvicorn/fastapi when tests only need the data classes.
def __getattr__(name):
    """Lazy import for server-specific names."""
    if name in {
        "DEFAULT_DIARIZATION_MODEL",
        "EMBEDDING_CACHE_DIR",
        "ENROLLMENT_DIR",
        "MAX_DURATION_SECONDS",
        "MAX_UPLOAD_BYTES",
        "SUPPORTED_FORMATS",
        "build_parser",
        "create_app",
        "main",
    }:
        from diarization import server
        return getattr(server, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")

if __name__ == "__main__":
    from diarization.server import main
    main()
