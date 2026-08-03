"""Synchronous pipeline helpers for embedding cache construction.

Isolated from the FastAPI layer so the cache build logic (audio decode
+ per-segment embedding) can be exercised and reasoned about without
importing the web stack.
"""

import logging

from .embeddings import EmbeddingExtractor, ShortSegmentSkipped

logger = logging.getLogger("diarization-server")


def build_cache_sync(
    temp_audio: str,
    segments: list[dict],
    recording_name: str,
    extractor: EmbeddingExtractor,
) -> dict:
    """Synchronous cache build: decode audio ONCE, then embed segments.

    Runs in a worker thread via asyncio.to_thread so the event loop is not
    blocked. CPU decode happens once; per-segment GPU work is serialized
    via extractor._gpu_lock, allowing different recordings to overlap their
    CPU decode while CUDA use remains safe.

    Returns dict with segment_embeddings, label_embeddings, excluded info,
    and segments_skipped_short count.
    """
    import torchaudio

    signal, sample_rate = torchaudio.load(temp_audio)
    if signal.shape[0] > 1:
        signal = signal.mean(dim=0, keepdim=True)

    logger.info(
        "Cache build %s: decoded audio once (%.1fs, sr=%d, %d segments to process)",
        recording_name,
        signal.shape[1] / sample_rate,
        sample_rate,
        len(segments),
    )

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

        segment_duration = end - start
        if segment_duration < extractor.MIN_SEGMENT_DURATION:
            segments_skipped_short += 1
            logger.info(
                "Skipping short segment %s [%.2f-%.2f] (%.2fs < %.2fs)",
                recording_name, start, end,
                segment_duration, extractor.MIN_SEGMENT_DURATION,
            )
            continue

        try:
            emb = extractor.extract_embedding_from_waveform(
                signal, sample_rate, start, end
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
        except ShortSegmentSkipped:
            segments_skipped_short += 1
        except Exception as e:
            excluded_segments.append({
                "label": label,
                "start": start,
                "end": end,
                "reason": "extraction_failed",
                "error": str(e),
            })
            label_failure_counts[label] = label_failure_counts.get(label, 0) + 1
            logger.error(
                "Failed to extract embedding for %s [%.2f-%.2f]: %s",
                recording_name, start, end, e,
            )

    return {
        "segment_embeddings": segment_embeddings,
        "label_embeddings": label_embeddings,
        "excluded_segments": excluded_segments,
        "label_failure_counts": label_failure_counts,
        "segments_skipped_short": segments_skipped_short,
    }
