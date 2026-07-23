"""Unit tests for cache-build resilience to short/invalid diarized segments.

Tests the core logic of segment filtering and prototype computation without
requiring the full FastAPI server or heavy ML dependencies.
"""
import numpy as np
import pytest
from unittest.mock import MagicMock


# ── Simulated core logic ─────────────────────────────────────────────────

def simulate_cache_build(segments, extractor_mock):
    """Simulate the cache-build logic from diarization-server.py.
    
    Returns:
        (prototypes, segment_embeddings, excluded_segments, excluded_labels, error)
    """
    segment_embeddings = []
    label_embeddings = {}
    excluded_segments = []
    label_failure_counts = {}
    
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
            emb = extractor_mock.extract_embedding_from_segment(None, start, end)
            segment_embeddings.append({
                "label": label,
                "start": start,
                "end": end,
                "duration": end - start,
                "embedding": emb.tolist() if hasattr(emb, 'tolist') else emb,
            })
            if label not in label_embeddings:
                label_embeddings[label] = []
            label_embeddings[label].append(emb)
        except Exception as e:
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
    
    # Check if we have any usable embeddings
    if not segment_embeddings:
        return None, None, excluded_segments, [], {
            "error": "no_usable_embeddings",
            "message": "No embeddings extracted from any segment",
            "excluded_count": len(excluded_segments),
        }
    
    # Compute per-label prototypes
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
            "embedding": mean_emb.tolist() if hasattr(mean_emb, 'tolist') else mean_emb,
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
        return None, None, excluded_segments, excluded_labels, {
            "error": "no_usable_label_prototypes",
            "message": "All labels excluded; no usable prototypes remain",
            "excluded_labels": excluded_labels,
        }
    
    return prototypes, segment_embeddings, excluded_segments, excluded_labels, None


# ── Fixtures ─────────────────────────────────────────────────────────────

@pytest.fixture
def mock_extractor():
    """Mock extractor that fails on segments < 0.3s."""
    extractor = MagicMock()
    
    def extract_side_effect(audio_path, start, end):
        duration = end - start
        if duration < 0.3:
            raise RuntimeError(f"Segment too short: {duration:.2f}s < 0.3s")
        # Return normalized embedding
        emb = np.random.randn(192).astype(np.float32)
        emb = emb / np.linalg.norm(emb)
        return emb
    
    extractor.extract_embedding_from_segment.side_effect = extract_side_effect
    return extractor


# ── Tests ────────────────────────────────────────────────────────────────

def test_mixed_valid_and_short_segments_succeeds(mock_extractor):
    """Cache build succeeds when some segments are short but others valid."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.5},  # valid
        {"speaker": "SPEAKER_00", "start": 2.0, "end": 2.2},  # too short
        {"speaker": "SPEAKER_01", "start": 3.0, "end": 4.5},  # valid
        {"speaker": "SPEAKER_01", "start": 5.0, "end": 5.1},  # too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, error = simulate_cache_build(
        segments, mock_extractor
    )
    
    # Should succeed
    assert error is None
    assert prototypes is not None
    assert len(prototypes) == 2  # both speakers
    assert len(seg_embs) == 2  # only valid segments
    
    # Should report exclusions
    assert len(excluded_segs) == 2
    assert all(s["reason"] == "segment_too_short" for s in excluded_segs)
    assert len(excluded_labels) == 0  # both labels have valid segments


def test_label_with_only_short_segments_excluded(mock_extractor):
    """Label with only short segments is excluded from prototypes."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.5},  # valid
        {"speaker": "SPEAKER_01", "start": 2.0, "end": 2.1},  # too short
        {"speaker": "SPEAKER_01", "start": 3.0, "end": 3.2},  # too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, error = simulate_cache_build(
        segments, mock_extractor
    )
    
    # Should succeed with one label
    assert error is None
    assert len(prototypes) == 1
    assert "SPEAKER_00" in prototypes
    assert len(seg_embs) == 1
    
    # SPEAKER_01 excluded
    assert len(excluded_segs) == 2
    assert len(excluded_labels) == 1
    assert excluded_labels[0]["label"] == "SPEAKER_01"
    assert excluded_labels[0]["reason"] == "all_segments_failed"
    assert excluded_labels[0]["failed_count"] == 2


def test_all_invalid_segments_fails_with_clear_error(mock_extractor):
    """Cache build fails with structured error when all segments invalid."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 0.1},  # too short
        {"speaker": "SPEAKER_01", "start": 1.0, "end": 1.2},  # too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, error = simulate_cache_build(
        segments, mock_extractor
    )
    
    # Should fail
    assert prototypes is None
    assert error is not None
    assert error["error"] == "no_usable_embeddings"
    assert error["excluded_count"] == 2
    assert len(excluded_segs) == 2
    assert all(s["reason"] == "segment_too_short" for s in excluded_segs)


def test_invalid_time_range_excluded(mock_extractor):
    """Segments with end <= start are excluded with reason."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 1.0, "end": 0.5},  # invalid
        {"speaker": "SPEAKER_00", "start": 2.0, "end": 2.0},  # invalid
        {"speaker": "SPEAKER_01", "start": 3.0, "end": 4.0},  # valid
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, error = simulate_cache_build(
        segments, mock_extractor
    )
    
    # Should succeed with one valid segment
    assert error is None
    assert len(prototypes) == 1
    assert len(seg_embs) == 1
    assert len(excluded_segs) == 2
    assert all(s["reason"] == "invalid_time_range" for s in excluded_segs)


def test_all_labels_excluded_fails(mock_extractor):
    """Cache build fails when all labels have only failed segments."""
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 0.1},  # too short
        {"speaker": "SPEAKER_01", "start": 1.0, "end": 1.1},  # too short
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, error = simulate_cache_build(
        segments, mock_extractor
    )
    
    # Should fail
    assert prototypes is None
    assert error is not None
    assert error["error"] == "no_usable_embeddings"


def test_extraction_failure_other_than_short(mock_extractor):
    """Non-short-segment extraction failures are tracked correctly."""
    # Make extractor fail with a different error
    def fail_with_other_error(audio_path, start, end):
        raise RuntimeError("Audio decode failed")
    
    mock_extractor.extract_embedding_from_segment.side_effect = fail_with_other_error
    
    segments = [
        {"speaker": "SPEAKER_00", "start": 0.0, "end": 1.0},
        {"speaker": "SPEAKER_01", "start": 2.0, "end": 3.0},
    ]
    
    prototypes, seg_embs, excluded_segs, excluded_labels, error = simulate_cache_build(
        segments, mock_extractor
    )
    
    # Should fail
    assert error is not None
    assert error["error"] == "no_usable_embeddings"
    assert len(excluded_segs) == 2
    # Should be marked as extraction_failed, not segment_too_short
    assert all(s["reason"] == "extraction_failed" for s in excluded_segs)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
