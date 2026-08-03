"""Embedding cache build and candidate-match endpoints.

Owns the /v1/identity/cache/* endpoints. Delegates the synchronous
audio-decode + embedding work to ``diarization.pipeline.build_cache_sync``.
"""

import asyncio
import json
import logging
import os
import tempfile
from pathlib import Path

import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from ..identity import cosine_similarity
from ..enrollment import MIN_ENROLLMENT_SAMPLES
from ..pipeline import build_cache_sync

logger = logging.getLogger("diarization-server")


def register_cache_routes(app: FastAPI) -> None:
    """Attach the /v1/identity/cache/* endpoints."""

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
        """
        embedding_cache = app.state.embedding_cache
        embedding_extractor = app.state.embedding_extractor
        recording_locks = app.state.recording_locks
        max_upload_bytes = app.state.max_upload_bytes

        if not transcript.filename or not transcript.filename.endswith(".json"):
            raise HTTPException(400, "transcript must be a .json file")

        try:
            transcript_bytes = await transcript.read()
            if len(transcript_bytes) > max_upload_bytes:
                raise HTTPException(413, "transcript too large")
            transcript_data = json.loads(transcript_bytes)
        except json.JSONDecodeError as e:
            raise HTTPException(400, f"Invalid transcript JSON: {e}")

        segments = transcript_data.get("segments", [])
        if not segments:
            raise HTTPException(400, "transcript has no segments")

        transcript_sha = embedding_cache._sha256_bytes(transcript_bytes)
        segment_set_hash = embedding_cache._segment_set_hash(segments)

        audio_sha = None
        temp_audio = None
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix=".audio") as tmp:
                audio_content = await audio.read()
                if len(audio_content) > max_upload_bytes:
                    raise HTTPException(413, "audio too large")
                tmp.write(audio_content)
                temp_audio = tmp.name

            audio_sha = embedding_cache._sha256_file(Path(temp_audio))

            lock = recording_locks.setdefault(recording_name, asyncio.Lock())
            async with lock:
                lookup = embedding_cache.lookup(audio_sha, transcript_sha, segment_set_hash)
                if lookup["status"] == "hit":
                    return {
                        "status": "hit",
                        "cache_id": lookup["cache_id"],
                        "recording_name": recording_name,
                        "label_count": lookup["manifest"].get("label_count", 0),
                        "segment_count": lookup["manifest"].get("segment_count", 0),
                        "segments_skipped_short": lookup["manifest"].get("segments_skipped_short", 0),
                    }

                build_result = await asyncio.to_thread(
                    build_cache_sync,
                    temp_audio, segments, recording_name, embedding_extractor,
                )

                segment_embeddings = build_result["segment_embeddings"]
                label_embeddings = build_result["label_embeddings"]
                excluded_segments = build_result["excluded_segments"]
                label_failure_counts = build_result["label_failure_counts"]
                segments_skipped_short = build_result["segments_skipped_short"]

                if not segment_embeddings:
                    raise HTTPException(
                        500,
                        {
                            "error": "no_usable_embeddings",
                            "message": "No embeddings extracted from any segment",
                            "excluded_count": len(excluded_segments),
                            "excluded_segments": excluded_segments[:20],
                        },
                    )

                prototypes = {}
                excluded_labels = []
                for label, embs in label_embeddings.items():
                    if not embs:
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

                all_labels_in_segments = set(seg.get("speaker", "UNKNOWN") for seg in segments)
                labels_with_prototypes = set(prototypes.keys())
                labels_without_prototypes = all_labels_in_segments - labels_with_prototypes
                for label in labels_without_prototypes:
                    excluded_labels.append({
                        "label": label,
                        "reason": "all_segments_failed",
                        "failed_count": label_failure_counts.get(label, 0),
                    })

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

                exclusion_metadata = {
                    "excluded_segment_count": len(excluded_segments),
                    "excluded_segments": excluded_segments,
                    "excluded_label_count": len(excluded_labels),
                    "excluded_labels": excluded_labels,
                    "segments_skipped_short": segments_skipped_short,
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
                    "segments_skipped_short": segments_skipped_short,
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
        cache_refs: str = Form(...),
    ):
        """Get candidate matches from cached embeddings.

        Compares person's enrolled centroid to recording label prototypes.
        Returns review-only candidates with supporting evidence.
        Never mutates mappings.
        """
        enrollment_store = app.state.enrollment_store
        embedding_cache = app.state.embedding_cache
        threshold = app.state.similarity_threshold
        margin = app.state.ambiguity_margin

        metadata = enrollment_store.get_metadata(person_id)
        if not metadata:
            raise HTTPException(404, f"Person not found: {person_id}")
        if not metadata.get("candidate_eligible"):
            raise HTTPException(
                400,
                f"Person {person_id} not eligible (need {MIN_ENROLLMENT_SAMPLES}+ samples)",
            )

        try:
            refs = json.loads(cache_refs)
            if not isinstance(refs, list):
                raise ValueError("cache_refs must be a list")
        except Exception as e:
            raise HTTPException(400, f"Invalid cache_refs JSON: {e}")

        person_embeddings = enrollment_store.get_embeddings(person_id)
        if not person_embeddings:
            raise HTTPException(400, f"No embeddings for {person_id}")
        centroid = np.mean(person_embeddings, axis=0)
        norm = np.linalg.norm(centroid)
        if norm > 0:
            centroid = centroid / norm

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

            for label, proto in prototypes.items():
                proto_emb = np.array(proto["embedding"])
                score = cosine_similarity(centroid, proto_emb)

                if score >= threshold:
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
