"""Persistent enrollment storage with atomic writes and owner-only permissions.

Directory structure:
    <enrollment_dir>/<person_id>/
        metadata.json  - person metadata and sample count
        embeddings.json - list of normalized speaker embeddings
"""

import json
import logging
import os
import stat
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

logger = logging.getLogger("diarization-server")

# Minimum number of enrollment samples before a person becomes
# candidate-eligible for identity matching.
MIN_ENROLLMENT_SAMPLES = 3


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
            "revision": 0,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }

        self._atomic_write(person_dir / "metadata.json", metadata)
        self._atomic_write(person_dir / "embeddings.json", {"embeddings": []})

        return metadata

    def add_sample(self, person_id: str, embedding: np.ndarray) -> dict:
        """Add a speaker embedding sample to an enrollment.

        Atomically persists the new embedding and bumps the monotonic
        ``revision`` counter.  Revision is the server-authoritative signal
        that the voice profile changed; clients use it to detect stale
        candidate-scan manifests.

        Atomicity invariant: if embeddings are persisted but metadata write
        fails, the next get_metadata call reconciles by detecting the mismatch
        between samples_count and actual embedding count, then bumps revision
        to reflect the true state.  This ensures any embedding change is
        observably revision-invalidating to clients.

        Migration: enrollments created before the revision field carry no
        ``revision`` key.  ``metadata.get("revision", 0)`` treats those as
        revision 0; the first successful add_sample writes revision 1.

        Args:
            person_id: Person identifier
            embedding: Normalized speaker embedding (1D numpy array)

        Returns:
            Updated metadata dict (always includes ``revision``)

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

        # Load metadata and bump revision (migrating legacy records with no revision)
        metadata_path = person_dir / "metadata.json"
        with open(metadata_path) as f:
            metadata = json.load(f)

        current_revision = metadata.get("revision", 0)
        new_revision = current_revision + 1
        metadata["revision"] = new_revision
        metadata["samples_count"] = len(data["embeddings"])
        metadata["candidate_eligible"] = metadata["samples_count"] >= MIN_ENROLLMENT_SAMPLES
        metadata["updated_at"] = datetime.now(timezone.utc).isoformat()

        # Persist embeddings first, then metadata.  If the metadata write
        # fails after embeddings succeed, reconciliation on next read will
        # detect the mismatch and bump revision.  Both writes use atomic
        # temp+rename.
        try:
            self._atomic_write(embeddings_path, data)
        except Exception as e:
            # Embeddings write failed — metadata is still consistent.
            raise RuntimeError(f"Failed to persist embeddings: {e}") from e

        try:
            self._atomic_write(metadata_path, metadata)
        except Exception as e:
            # Metadata write failed after embeddings persisted.
            # The next get_metadata call will reconcile by detecting
            # samples_count mismatch and bumping revision.
            # Do NOT claim success — raise to caller.
            raise RuntimeError(f"Failed to persist metadata after embeddings written: {e}") from e

        return metadata

    def get_metadata(self, person_id: str) -> dict | None:
        """Get metadata for a person, or None if not found.

        Always returns a ``revision`` field.  Legacy enrollments created
        before the revision contract are normalized to revision 0 on read
        (not persisted — migration happens on next write via add_sample).

        Reconciliation: if samples_count in metadata doesn't match the actual
        embedding count (e.g., from a partial write where embeddings persisted
        but metadata write failed), the revision is bumped to reflect the true
        state.  This ensures any embedding change is observably revision-
        invalidating to clients.
        """
        person_dir = self._person_dir(person_id)
        metadata_path = person_dir / "metadata.json"
        embeddings_path = person_dir / "embeddings.json"

        if not metadata_path.exists():
            return None

        with open(metadata_path) as f:
            metadata = json.load(f)

        # Normalize: legacy enrollments without revision default to 0.
        metadata.setdefault("revision", 0)

        # Reconciliation: check if samples_count matches actual embedding count.
        # If not, embeddings were written but metadata wasn't updated — bump revision.
        if embeddings_path.exists():
            with open(embeddings_path) as f:
                embeddings_data = json.load(f)
            actual_count = len(embeddings_data.get("embeddings", []))
            stored_count = metadata.get("samples_count", 0)

            if actual_count != stored_count:
                # Embeddings changed but metadata is stale — bump revision.
                metadata["revision"] = metadata["revision"] + 1
                metadata["samples_count"] = actual_count
                metadata["candidate_eligible"] = actual_count >= MIN_ENROLLMENT_SAMPLES
                metadata["updated_at"] = datetime.now(timezone.utc).isoformat()

                # Persist the reconciled metadata.
                try:
                    self._atomic_write(metadata_path, metadata)
                except Exception:
                    # If reconciliation write fails, return the corrected
                    # metadata anyway — the next read will retry reconciliation.
                    pass

        return metadata

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
                        "revision": metadata.get("revision", 0),
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
                    # Normalize revision for legacy enrollments
                    metadata.setdefault("revision", 0)
                    persons.append(metadata)
                except Exception as e:
                    logger.warning("Failed to read metadata for %s: %s", person_dir.name, e)

        return persons
