"""Unit tests for cache-build resilience to short/invalid diarized segments.

Tests the core logic of segment filtering and prototype computation without
requiring the full FastAPI server or heavy ML dependencies.

Semantics (post-fix):
- Short segments (<0.3s) are pre-filtered BEFORE calling the extractor.
- They are counted as `segments_skipped_short`, not as failures.
- They do NOT appear in `excluded_segments` (which is for genuine failures).
- Real extractor failures (CUDA/audio errors) remain errors.
"""
import pytest
from unittest.mock import MagicMock


# ── Simulated core logic (mirrors diarization-server.py cache handler) ───

MIN_SEGMENT_DURATION = 0.3


class ShortSegmentSkipped(Exception):
    """Mirrors the server-side exception."""
    pass


def simulate_cache_build(segments, extractor_mock):
    """Simulate the cache-build logic from diarization-server.py.
    
    Returns:
        (prototypes, segment_embeddings, excluded_segments, excluded_labels,
         segments_skipped_short, error)
    """
    segment_embeddings = []
    label_embeddings = {}
    excluded_segments = []
    label_failure_counts = {}
    segments_skipped_short = 0
    
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
        
        # Pre-filter by duration BEFORE calling extractor
        segment_duration = end - start
        if segment_duration < MIN_SEGMENT_DURATION:
            segments_skipped_short += 1
            continue
        
        try:
            emb = extractor_mock.extract_embedding_from_segment(None, start, end)
            # emb is a list (mock returns list)
            emb_list = emb if isinstance(emb, list) else (emb.tolist() if hasattr(emb, 'tolist') else emb)
            segment_embeddings.append({
                "label": label,
                "start": start,
                "end": end,
                "duration": end - start,
                "embedding": emb_list,
            })
            if label not in label_embeddings:
                label_embeddings[label] = []
            label_embeddings[label].append(emb_list)
        except ShortSegmentSkipped:
            # Defense in depth — extractor's own guard caught it.
            segments_skipped_short += 1
        except Exception as e:
            # Genuine extraction failure
            excluded_segments.append({
                "label": label,
                "start": start,
                "end": end,
                "reason": "extraction_failed",
                "error": str(e),
            })
            label_failure_counts[label] = label_failure_counts.get(label, 0) + 1
    
    # Check if we have any usable embeddings
    if not segment_embeddings:
        return None, None, excluded_segments, [], segments_skipped_short, {
            "error": "no_usable_embeddings",
            "message": "No embeddings extracted from any segment",
            "excluded_count": len(excluded_segments),
            "skipped_short": segments_skipped_short,
        }
    
    # Compute per-label prototypes (simplified — no numpy)
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
        # Simplified: just use first embedding as prototype (no mean/norm)
        prototypes[label] = {
            "embedding": embs[0],
            "segment_count": len(embs),
        }
    
    # Identify labels with only failures
    all_labels = set(seg.get("speaker", "UNKNOWN") for seg in segments)
    labels_with_prototypes = set(prototypes.keys())
    labels_without = all_labels - labels_with_prototypes
    for label in labels_without:
        excluded_labels.append({
            "label": label,
            "reason": "all_segments_failed",
            "failed_count": label_failure_counts.get(label, 0),
        })
    
    # Fail if zero prototypes
    if not prototypes:
        return None, None, excluded_segments, excluded_labels, segments_skipped_short, {
            "error": "no_usable_label_prototypes",
            "message": "All labels excluded; no usable prototypes remain",
            "excluded_labels": excluded_labels,
        }
    
    return prototypes, segment_embeddings, excluded_segments, excluded_labels, segments_skipped_short, None


# ── Fixtures ─────────────────────────────────────────────────────────────

@pytest.fixture
def mock_extractor():
    """Mock extractor that raises ShortSegmentSkipped for < 0.3s segments."""
    extractor = MagicMock()
    
    def extract_side_effect(audio_path, start, end):
        duration = end - start
        if duration < MIN_SEGMENT_DURATION:
            raise ShortSegmentSkipped(f"Segment too short: {duration:.2f}s < {MIN_SEGMENT_DURATION}s")
        # Return mock embedding (list of floats)
        return [0.1] * 192
    
    extractor.extract_embedding_from_segment.side_effect = extract_side_effect
    return extractor


# ── Tests ────────────────────────────────────────────────────────────────

def test_short_segment_does_not_call_extractor(mock_extractor):
    """0.22s segment is pre-filtered; extractor is never called for it."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.5},  # valid
        {"speaker": "SPEAKER_00", "start": 2.0, "end": 2.22},  # 0.22s — too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, skipped_short, error = \
        simulate_cache_build(segments, mock_extractor)
    
    # Extractor called only once (for the valid segment)
    assert mock_extractor.extract_embedding_from_segment.call_count == 1
    call_args = mock_extractor.extract_embedding_from_segment.call_args
    assert call_args[0][1] == 0.0 and call_args[0][2] == 1.5
    
    # Build succeeds
    assert error is None
    assert len(prototypes) == 1
    assert len(seg_embs) == 1
    
    # Short segment counted as skip, not failure
    assert skipped_short == 1
    assert len(excluded_segs) == 0  # no genuine failures


def test_mixed_valid_and_short_segments_succeeds(mock_extractor):
    """Cache build succeeds when some segments are short but others valid."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.5},  # valid
        {"speaker": "SPEAKER_00", "start": 2.0, "end": 2.2},  # too short
        {"speaker": "SPEAKER_01", "start": 3.0, "end": 4.5},  # valid
        {"speaker": "SPEAKER_01", "start": 5.0, "end": 5.1},  # too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, skipped_short, error = \
        simulate_cache_build(segments, mock_extractor)
    
    # Should succeed
    assert error is None
    assert prototypes is not None
    assert len(prototypes) == 2  # both speakers
    assert len(seg_embs) == 2  # only valid segments
    
    # Short segments counted separately
    assert skipped_short == 2
    assert len(excluded_segs) == 0  # no genuine failures
    assert len(excluded_labels) == 0  # both labels have valid segments


def test_label_with_only_short_segments_excluded(mock_extractor):
    """Label with only short segments is excluded from prototypes."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.5},  # valid
        {"speaker": "SPEAKER_01", "start": 2.0, "end": 2.1},  # too short
        {"speaker": "SPEAKER_01", "start": 3.0, "end": 3.2},  # too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, skipped_short, error = \
        simulate_cache_build(segments, mock_extractor)
    
    # Should succeed with one label
    assert error is None
    assert len(prototypes) == 1
    assert "SPEAKER_00" in prototypes
    assert len(seg_embs) == 1
    
    # Skips counted
    assert skipped_short == 2
    # SPEAKER_01 excluded (no valid segments)
    assert len(excluded_labels) == 1
    assert excluded_labels[0]["label"] == "SPEAKER_01"
    # Note: label_failure_counts is NOT incremented for skips, so failed_count is 0
    assert excluded_labels[0]["failed_count"] == 0


def test_all_short_segments_fails_with_clear_error(mock_extractor):
    """Cache build fails when all segments are too short."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 0.1},  # too short
        {"speaker": "SPEAKER_01", "start": 1.0, "end": 1.2},  # too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, skipped_short, error = \
        simulate_cache_build(segments, mock_extractor)
    
    # Should fail
    assert prototypes is None
    assert error is not None
    assert error["error"] == "no_usable_embeddings"
    assert error["skipped_short"] == 2
    # No genuine failures
    assert len(excluded_segs) == 0
    assert skipped_short == 2


def test_invalid_time_range_excluded(mock_extractor):
    """Segments with end <= start are excluded with reason."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 1.0, "end": 0.5},  # invalid
        {"speaker": "SPEAKER_00", "start": 2.0, "end": 2.0},  # invalid
        {"speaker": "SPEAKER_01", "start": 3.0, "end": 4.0},  # valid
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, skipped_short, error = \
        simulate_cache_build(segments, mock_extractor)
    
    # Should succeed with one valid segment
    assert error is None
    assert len(prototypes) == 1
    assert len(seg_embs) == 1
    assert len(excluded_segs) == 2
    assert all(s["reason"] == "invalid_time_range" for s in excluded_segs)
    assert skipped_short == 0


def test_extraction_failure_other_than_short(mock_extractor):
    """Non-short-segment extraction failures are tracked as errors."""
    # Make extractor fail with a different error
    def fail_with_other_error(audio_path, start, end):
        raise RuntimeError("CUDA out of memory")
    
    mock_extractor.extract_embedding_from_segment.side_effect = fail_with_other_error
    
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.0},
        {"speaker": "SPEAKER_01", "start": 2.0, "end": 3.0},
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, skipped_short, error = \
        simulate_cache_build(segments, mock_extractor)
    
    # Should fail
    assert error is not None
    assert error["error"] == "no_usable_embeddings"
    assert len(excluded_segs) == 2
    # Should be marked as extraction_failed, not skipped
    assert all(s["reason"] == "extraction_failed" for s in excluded_segs)
    assert skipped_short == 0


def test_defense_in_depth_extractor_raises_short_segment_skipped(mock_extractor):
    """If extractor raises ShortSegmentSkipped (defense in depth), it's counted as skip."""
    # Force extractor to raise ShortSegmentSkipped even for valid-duration segments
    def raise_short(audio_path, start, end):
        raise ShortSegmentSkipped("Segment too short")
    
    mock_extractor.extract_embedding_from_segment.side_effect = raise_short
    
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.0},  # valid duration
        {"speaker": "SPEAKER_01", "start": 2.0, "end": 3.0},  # valid duration
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, skipped_short, error = \
        simulate_cache_build(segments, mock_extractor)
    
    # Should fail (no usable embeddings)
    assert error is not None
    # But counted as skips, not failures
    assert skipped_short == 2
    assert len(excluded_segs) == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
