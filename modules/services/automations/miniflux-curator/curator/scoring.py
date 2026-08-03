"""Reference selection and entry scoring for the Miniflux curator.

Owns the tag-balanced reference bookmark selection, batched reference
embedding construction, per-entry scoring against reference embeddings,
and the per-run summary log line.
"""

import logging

import numpy as np

from .clients import cosine_similarity, get_embeddings, get_karakeep_bookmarks
from .titles import (
    build_bookmark_text,
    build_entry_text,
    get_bookmark_reference_title,
    get_bookmark_title,
    get_tag_names,
    normalize_title,
)


def select_reference_bookmarks(bookmarks, reference_limit):
    """Select a tag-balanced reference set, then fill by recency."""
    eligible_bookmarks = []
    poor_title_count = 0
    for bookmark in bookmarks:
        if get_bookmark_reference_title(bookmark):
            eligible_bookmarks.append(bookmark)
        else:
            poor_title_count += 1

    if poor_title_count:
        logging.info(
            "Skipped %s/%s Karakeep bookmarks with poor reference titles",
            poor_title_count,
            len(bookmarks),
        )

    selected = []
    selected_ids = set()
    covered_tags = set()

    for bookmark in eligible_bookmarks:
        if len(selected) >= reference_limit:
            break

        bookmark_id = bookmark.get("id")
        if bookmark_id in selected_ids:
            continue

        tags = get_tag_names(bookmark)
        if tags and any(tag not in covered_tags for tag in tags):
            selected.append(bookmark)
            selected_ids.add(bookmark_id)
            covered_tags.update(tags)

    for bookmark in eligible_bookmarks:
        if len(selected) >= reference_limit:
            break

        bookmark_id = bookmark.get("id")
        if bookmark_id not in selected_ids:
            selected.append(bookmark)
            selected_ids.add(bookmark_id)

    logging.info(
        f"Selected {len(selected)}/{len(eligible_bookmarks)} eligible "
        f"Karakeep bookmarks ({poor_title_count} skipped for poor titles) "
        f"covering {len(covered_tags)} tags for references"
    )
    return selected, len(covered_tags), poor_title_count


def get_reference_embeddings(
    karakeep_url, karakeep_api_key, embed_host, embed_model,
    fetch_limit=100, reference_limit=50, batch_size=64
):
    """Fetch Karakeep bookmarks and compute embeddings in batches."""
    bookmarks = get_karakeep_bookmarks(
        karakeep_url, karakeep_api_key, fetch_limit
    )
    stats = {
        "karakeep_bookmarks_fetched": len(bookmarks),
        "karakeep_references_selected": 0,
        "karakeep_tag_coverage_count": 0,
        "karakeep_bookmarks_skipped_poor_titles": 0,
    }

    if not bookmarks:
        logging.warning("No Karakeep bookmarks found")
        return [], stats

    (
        bookmarks,
        tag_coverage_count,
        poor_title_count,
    ) = select_reference_bookmarks(bookmarks, reference_limit)
    stats["karakeep_references_selected"] = len(bookmarks)
    stats["karakeep_tag_coverage_count"] = tag_coverage_count
    stats["karakeep_bookmarks_skipped_poor_titles"] = poor_title_count
    if not bookmarks:
        logging.warning("No Karakeep bookmarks selected for references")
        return [], stats

    logging.info(
        f"Computing embeddings for {len(bookmarks)} Karakeep bookmarks "
        f"(batch_size={batch_size})..."
    )
    reference_embeddings = []

    for i in range(0, len(bookmarks), batch_size):
        batch = bookmarks[i:i + batch_size]
        texts = [build_bookmark_text(bookmark) for bookmark in batch]

        try:
            embeddings = get_embeddings(texts, embed_host, embed_model)
            for bookmark, emb in zip(batch, embeddings):
                reference_embeddings.append({
                    "id": bookmark["id"],
                    "title": get_bookmark_title(bookmark),
                    "embedding": emb
                })
            processed = min(i + batch_size, len(bookmarks))
            logging.info(
                "  Processed "
                f"{processed}/{len(bookmarks)} Karakeep bookmarks..."
            )
        except Exception as e:
            logging.error(
                f"Failed to process batch of Karakeep bookmarks: {e}"
            )

    return reference_embeddings, stats


def log_run_summary(reference_stats, unread_count, threshold, below_threshold,
                    dry_run):
    """Emit a journald-visible summary for successful curator runs."""
    logging.warning(
        "Curator run complete: "
        "karakeep_bookmarks_fetched=%s, "
        "karakeep_references_selected=%s, "
        "karakeep_tag_coverage_count=%s, "
        "karakeep_bookmarks_skipped_poor_titles=%s, "
        "unread_entries_considered=%s, "
        "threshold=%s, "
        "below_threshold=%s, "
        "would_mark_read=%s, "
        "dry_run=%s",
        reference_stats["karakeep_bookmarks_fetched"],
        reference_stats["karakeep_references_selected"],
        reference_stats["karakeep_tag_coverage_count"],
        reference_stats["karakeep_bookmarks_skipped_poor_titles"],
        unread_count,
        threshold,
        below_threshold,
        below_threshold,
        dry_run,
    )


def score_entries_batch(
    entries, reference_embeddings, embed_host, embed_model, batch_size=64
):
    """Score multiple entries based on similarity to saved references."""
    if not reference_embeddings:
        return [
            (entry["id"], entry["title"], 5.0,
             "No saved references to compare against")
            for entry in entries
        ]

    texts = [build_entry_text(entry) for entry in entries]

    all_embeddings = []
    for i in range(0, len(texts), batch_size):
        batch_texts = texts[i:i + batch_size]
        try:
            batch_embs = get_embeddings(batch_texts, embed_host, embed_model)
            all_embeddings.extend(batch_embs)
        except Exception as e:
            logging.error(f"Failed to get embeddings for batch: {e}")
            all_embeddings.extend([None] * len(batch_texts))

    scored = []
    for entry, entry_emb in zip(entries, all_embeddings):
        if entry_emb is None:
            title = normalize_title(entry["title"])
            scored.append((entry["id"], title, 5.0, "Failed to get embedding"))
            continue

        entry_emb_array = np.array(entry_emb)
        max_sim = 0.0
        best_match = None

        for reference in reference_embeddings:
            sim = cosine_similarity(
                entry_emb_array, np.array(reference["embedding"])
            )
            if sim > max_sim:
                max_sim = sim
                best_match = reference["title"]

        score = round(max_sim * 10, 1)

        if score >= 7.0 and best_match is not None:
            reason = f"Strong match to saved reference: '{best_match[:50]}...'"
        elif score >= 4.5:
            reason = "Moderate similarity to saved content"
        else:
            reason = "Low similarity to saved references"

        title = normalize_title(entry["title"])
        scored.append((entry["id"], title, score, reason))

    return scored
