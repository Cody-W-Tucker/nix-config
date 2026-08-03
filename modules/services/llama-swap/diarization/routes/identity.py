"""Speaker enrollment and identity routes.

Owns the enrollment endpoints (initialization, sample upload, candidate
listing, per-person status, and inventory). All heavy lifting lives in
``EnrollmentStore`` (``diarization.enrollment``); this module is pure
HTTP-shape code.
"""

import logging
import os
import tempfile
from pathlib import Path

from fastapi import FastAPI, File, HTTPException, UploadFile, Form

from ..enrollment import MIN_ENROLLMENT_SAMPLES

logger = logging.getLogger("diarization-server")


def register_identity_routes(app: FastAPI) -> None:
    """Attach the /v1/identity/* enrollment endpoints."""

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
        enrollment_store = app.state.enrollment_store
        enrollment_dir = app.state.enrollment_dir

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

        Extracts speaker embedding (CUDA-only) and stores it. Does not retain
        raw audio. Requires enrollment to be initialized first.

        Returns 400 if audio invalid or extraction fails.
        Returns 404 if enrollment not found.
        """
        enrollment_store = app.state.enrollment_store
        embedding_extractor = app.state.embedding_extractor
        supported_formats = app.state.supported_formats
        max_upload_bytes = app.state.max_upload_bytes

        metadata = enrollment_store.get_metadata(person_id)
        if metadata is None:
            raise HTTPException(
                status_code=404,
                detail=f"Enrollment not found for {person_id}. Initialize first via /v1/identity/enroll.",
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

        if len(audio_bytes) < 1000:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Audio file too small: {len(audio_bytes)} bytes. "
                    "Minimum ~1 second of audio required."
                ),
            )

        temp_path = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                tmp.write(audio_bytes)
                temp_path = tmp.name

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
        """List enrolled speakers who meet the sample threshold."""
        enrollment_store = app.state.enrollment_store
        enrollment_dir = app.state.enrollment_dir
        candidates = enrollment_store.list_candidates()

        return {
            "status": "ok",
            "candidates": candidates,
            "min_samples_required": MIN_ENROLLMENT_SAMPLES,
            "total_enrolled": len(list(enrollment_dir.iterdir())) if enrollment_dir.exists() else 0,
        }

    @app.get("/v1/identity/status/{person_id}")
    async def enrollment_status(person_id: str):
        """Get enrollment status for a specific person."""
        enrollment_store = app.state.enrollment_store
        metadata = enrollment_store.get_metadata(person_id)
        if metadata is None:
            raise HTTPException(
                status_code=404,
                detail=f"Enrollment not found for {person_id}",
            )

        return metadata

    @app.get("/v1/identity/inventory")
    async def enrollment_inventory():
        """List all enrolled persons with sample counts, eligibility, updated time."""
        enrollment_store = app.state.enrollment_store
        persons = enrollment_store.list_persons()
        return {
            "persons": persons,
            "min_samples_required": MIN_ENROLLMENT_SAMPLES,
            "total": len(persons),
        }
