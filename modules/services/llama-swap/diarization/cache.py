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

import json
import logging
import os
import stat
import tempfile
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger("diarization-server")


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
            manifest["segments_skipped_short"] = exclusion_metadata.get("segments_skipped_short", 0)

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
