# Miniflux Auto-Curator
# Uses vector similarity between saved Karakeep bookmarks and unread entries to
# auto-mark low-relevance articles as read.

import json
import logging
import os
import re
import urllib.error
import urllib.parse
import urllib.request

import miniflux
import numpy as np


MIN_REFERENCE_TITLE_CHARS = 4
BARE_SOURCE_TITLES = {
    "x",
    "twitter",
    "threads",
    "facebook",
    "instagram",
    "linkedin",
    "reddit",
    "youtube",
    "medium",
    "substack",
    "mastodon",
    "bluesky",
    "bsky",
}


def load_state(state_file):
    """Load the last processed entry ID from state file."""
    if os.path.exists(state_file):
        try:
            with open(state_file, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            logging.warning(f"Could not load state file: {e}")
    return {"last_processed_id": 0}


def save_state(state_file, state):
    """Save the last processed entry ID to state file."""
    try:
        # Ensure directory exists
        os.makedirs(os.path.dirname(state_file), exist_ok=True)
        with open(state_file, 'w') as f:
            json.dump(state, f)
    except IOError as e:
        logging.error(f"Could not save state file: {e}")


def cosine_similarity(a, b):
    """Calculate cosine similarity between two vectors."""
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


def get_embeddings(texts, host, model):
    """Get embeddings for multiple texts via OpenAI-compatible API (batch)."""
    import urllib.request
    import urllib.error

    data = json.dumps({
        "model": model,
        "input": texts
    }).encode()

    req = urllib.request.Request(
        f"{host}/v1/embeddings",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode())
            # Return embeddings in same order as input
            return [item["embedding"] for item in result["data"]]
    except urllib.error.URLError as e:
        logging.error(f"Failed to get embeddings: {e}")
        raise


def get_embedding(text, host, model):
    """Get embedding for a single text (convenience wrapper)."""
    return get_embeddings([text], host, model)[0]


def normalize_title(title):
    """Remove conservative source-wrapper chrome from feed titles."""
    if not title:
        return ""

    normalized = re.sub(r"\s+", " ", str(title)).strip()
    normalized = strip_title_source_suffix(normalized)

    quoted = extract_wrapped_quoted_title(normalized)
    if quoted:
        normalized = strip_title_source_suffix(quoted)

    return normalized or str(title)


def strip_title_source_suffix(title):
    """Strip obvious trailing site markers without touching short titles."""
    stripped = title.strip()
    for separator in (" | ", " / ", " - "):
        if separator not in stripped:
            continue

        before, after = stripped.rsplit(separator, 1)
        before = before.strip()
        after = after.strip()
        if is_source_suffix(before, after, separator):
            return before

    return stripped


def is_source_suffix(title, suffix, separator):
    """Return True when suffix looks like publisher/source chrome."""
    if len(title) < 12 or not suffix or len(suffix) > 40:
        return False

    known_markers = {"x", "twitter"}
    if suffix.lower() in known_markers:
        return True

    looks_like_domain = re.fullmatch(
        r"[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+",
        suffix,
    )
    if looks_like_domain:
        return True

    source_words = suffix.split()
    source_like_words = all(
        re.fullmatch(r"[A-Z][A-Za-z0-9&.]*|[A-Z0-9&.]{2,}", word)
        for word in source_words
    )
    if not source_like_words:
        return False

    if separator in (" | ", " / "):
        return True

    return len(title) >= 30 and len(source_words) <= 4


def extract_wrapped_quoted_title(title):
    """Extract quoted content from clear attribution wrappers."""
    match = re.fullmatch(
        r"([^:]{1,120}):\s*[\"“”‘’'](.+?)[\"“”‘’']\s*",
        title,
    )
    if not match:
        return None

    prefix = match.group(1).strip()
    quoted = re.sub(r"\s+", " ", match.group(2)).strip()
    if len(quoted) < 12:
        return None

    attribution_cue = re.search(
        r"(@\w+|\b(on|via|from|at)\s+[A-Za-z0-9][\w .-]{0,40}$|"
        r"\b(posted|shared|wrote|writes|says)\b)",
        prefix,
        re.IGNORECASE,
    )
    if attribution_cue:
        return quoted

    return None


def is_good_reference_title(title):
    """Return True when a normalized bookmark title is worth embedding."""
    normalized = re.sub(r"\s+", " ", str(title or "")).strip()
    if not normalized:
        return False

    semantic_chars = re.sub(r"[^A-Za-z0-9]+", "", normalized)
    if len(semantic_chars) < MIN_REFERENCE_TITLE_CHARS:
        return False

    source_key = re.sub(r"[^A-Za-z0-9]+", "", normalized).lower()
    return source_key not in BARE_SOURCE_TITLES


def get_bookmark_reference_title(bookmark):
    """Return a normalized bookmark title only if it is safe as a reference."""
    content = bookmark.get("content")
    if isinstance(content, dict) and content.get("title"):
        title = normalize_title(content["title"])
    elif bookmark.get("title"):
        title = normalize_title(bookmark["title"])
    else:
        return ""

    if not is_good_reference_title(title):
        return ""
    return title


def build_bookmark_text(bookmark):
    """Build clean title-only embedding text for Karakeep references."""
    return get_bookmark_reference_title(bookmark)


def build_entry_text(entry):
    """Build clean title-only embedding text for unread Miniflux entries."""
    return normalize_title(entry.get("title"))


def get_bookmark_title(bookmark):
    """Return the best available bookmark title for logging/scoring reasons."""
    content = bookmark.get("content")
    if isinstance(content, dict) and content.get("title"):
        return normalize_title(content["title"])
    if bookmark.get("title"):
        return normalize_title(bookmark["title"])
    return "Untitled bookmark"


def get_tag_names(bookmark):
    """Extract tag names from Karakeep bookmark payloads."""
    names = []
    for tag in bookmark.get("tags") or []:
        if isinstance(tag, dict):
            name = tag.get("name")
        else:
            name = tag
        if name:
            names.append(str(name))
    return names


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


def get_karakeep_bookmarks(host, api_key, limit=100):
    """Fetch saved bookmarks from Karakeep using cursor pagination."""
    logging.info("Fetching Karakeep bookmarks...")
    bookmarks = []
    cursor = None
    base_url = host.rstrip("/")

    try:
        while len(bookmarks) < limit:
            page_limit = min(100, limit - len(bookmarks))
            params = {"limit": page_limit}
            if cursor:
                params["cursor"] = cursor

            query = urllib.parse.urlencode(params)
            url = f"{base_url}/api/v1/bookmarks?{query}"
            req = urllib.request.Request(
                url,
                headers={"Authorization": f"Bearer {api_key}"},
                method="GET"
            )

            with urllib.request.urlopen(req, timeout=60) as response:
                result = json.loads(response.read().decode())

            batch = result.get("bookmarks") or []
            if not batch:
                break

            bookmarks.extend(batch)
            cursor = result.get("nextCursor")
            logging.info(f"  Fetched {len(bookmarks)} Karakeep bookmarks...")
            if not cursor:
                break
    except (urllib.error.URLError, json.JSONDecodeError, KeyError) as e:
        logging.error(f"Failed to fetch Karakeep bookmarks: {e}")
        return []

    return bookmarks


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

    # Process in batches
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

    # Prepare all texts and get embeddings in batch
    texts = [build_entry_text(entry) for entry in entries]

    # Get all embeddings at once (process in sub-batches if needed)
    all_embeddings = []
    for i in range(0, len(texts), batch_size):
        batch_texts = texts[i:i + batch_size]
        try:
            batch_embs = get_embeddings(batch_texts, embed_host, embed_model)
            all_embeddings.extend(batch_embs)
        except Exception as e:
            logging.error(f"Failed to get embeddings for batch: {e}")
            # Add None for failed embeddings - will get neutral scores
            all_embeddings.extend([None] * len(batch_texts))

    # Score each entry against reference embeddings
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

        # Scale to 0-10 for threshold compatibility
        score = round(max_sim * 10, 1)

        # Generate reason based on score
        if score >= 7.0 and best_match is not None:
            reason = f"Strong match to saved reference: '{best_match[:50]}...'"
        elif score >= 4.5:
            reason = "Moderate similarity to saved content"
        else:
            reason = "Low similarity to saved references"

        title = normalize_title(entry["title"])
        scored.append((entry["id"], title, score, reason))

    return scored


def main():
    # Read configuration from environment variables
    miniflux_url = os.environ.get("MINIFLUX_URL")
    api_key = os.environ.get("MINIFLUX_API_KEY")
    karakeep_url = os.environ.get("KARAKEEP_URL")
    karakeep_api_key = os.environ.get("KARAKEEP_API_KEY")
    embed_host = os.environ.get("OPENAI_HOST")
    embed_model = os.environ.get("EMBED_MODEL", "qwen3-embedding-8b")
    batch_size = int(os.environ.get("BATCH_SIZE", "64"))
    karakeep_fetch_limit = int(os.environ.get("KARAKEEP_FETCH_LIMIT", "100"))
    reference_limit = int(os.environ.get("REFERENCE_LIMIT", "50"))
    auto_mark_read_below = float(os.environ.get("AUTO_MARK_READ_BELOW", "3.5"))
    limit_unread = int(os.environ.get("LIMIT_UNREAD", "400"))
    dry_run = os.environ.get("DRY_RUN", "true").lower() == "true"
    state_file = os.environ.get(
        "STATE_FILE", "/var/lib/miniflux-curator/state.json"
    )

    logging.basicConfig(
        level=logging.INFO if dry_run else logging.WARNING,
        format="%(asctime)s - %(levelname)s - %(message)s"
    )

    # Validate required environment variables
    if not miniflux_url:
        logging.error("MINIFLUX_URL environment variable not set")
        return
    if not api_key:
        logging.error("MINIFLUX_API_KEY environment variable not set")
        return
    if not karakeep_url:
        logging.error("KARAKEEP_URL environment variable not set")
        return
    if not karakeep_api_key:
        logging.error("KARAKEEP_API_KEY environment variable not set")
        return
    if not embed_host:
        logging.error("OPENAI_HOST environment variable not set")
        return

    # Initialize Miniflux client
    client = miniflux.Client(miniflux_url, api_key=api_key)

    # Load state to track last processed entry
    state = load_state(state_file)
    last_processed_id = state.get("last_processed_id", 0)
    logging.info(f"Last processed entry ID: {last_processed_id}")

    # Get reference embeddings from Karakeep
    logging.warning(
        "Starting Miniflux curator using Karakeep references: "
        "dry_run=%s, threshold=%s",
        dry_run,
        auto_mark_read_below,
    )

    reference_embeddings, reference_stats = get_reference_embeddings(
        karakeep_url, karakeep_api_key, embed_host, embed_model,
        fetch_limit=karakeep_fetch_limit,
        reference_limit=reference_limit,
        batch_size=batch_size
    )

    if not reference_embeddings:
        logging.warning("Cannot proceed without Karakeep bookmarks. Exiting.")
        return

    # Use after_entry_id to only fetch entries we haven't processed yet
    logging.info(
        "Fetching unread entries with ID > "
        f"{last_processed_id}..."
    )
    unread = []
    after_id = last_processed_id
    limit_per_batch = 100
    max_total = limit_unread

    while len(unread) < max_total:
        batch = client.get_entries(
            status="unread",
            limit=limit_per_batch,
            after_entry_id=after_id,
            order="id",
            direction="asc"
        )["entries"]
        if not batch:
            break
        unread.extend(batch)
        # Update after_id to the last entry's ID to get next batch
        after_id = batch[-1]["id"]
        logging.info(f"  Fetched {len(unread)} unread entries...")
        # Prevent infinite loop if we got entries but all have same ID
        if len(batch) < limit_per_batch:
            break

    if not unread:
        logging.info("No new unread entries to process.")
        log_run_summary(
            reference_stats, 0, auto_mark_read_below, 0, dry_run
        )
        return

    logging.info(
        f"Processing {len(unread)} unread entries (batch_size={batch_size})..."
    )

    # Score all entries in batches
    scored_results = score_entries_batch(
        unread, reference_embeddings, embed_host, embed_model, batch_size
    )

    # Convert to expected format
    scored = []
    for entry_id, title, score, reason in scored_results:
        scored.append({
            "id": entry_id,
            "title": title,
            "score": score,
            "reason": reason
        })
        if len(scored) % 10 == 0:
            logging.info(f"  Scored {len(scored)}/{len(unread)} entries...")

    logging.info(f"  Scored {len(scored)}/{len(unread)} entries...")

    # Sort by score descending
    scored.sort(key=lambda x: x["score"], reverse=True)

    # Determine actions
    threshold = auto_mark_read_below
    dry_run = dry_run

    to_mark_read = [item["id"] for item in scored if item["score"] < threshold]

    # Log summary
    logging.info("\n=== SUMMARY ===")
    logging.info(f"Total unread processed: {len(unread)}")
    logging.info(
        f"Karakeep bookmarks used as reference: {len(reference_embeddings)}"
    )
    logging.info(f"Entries below threshold ({threshold}): {len(to_mark_read)}")
    logging.info(
        f"High-relevance entries kept: {len(unread) - len(to_mark_read)}"
    )

    if dry_run:
        logging.info("\n=== DRY RUN - No changes made ===")
        logging.info(f"Would mark {len(to_mark_read)} entries as read:")
        for item in scored:
            if item["score"] < threshold:
                logging.info(
                    f"  - [{item['score']:.1f}] {item['title'][:60]}..."
                )
        max_id = max(e["id"] for e in unread)
        logging.info(
            f"\nWould update state to last_processed_id={max_id}"
        )
    else:
        if to_mark_read:
            logging.info(
                f"Marking {len(to_mark_read)} low-relevance entries as read..."
            )
            client.update_entries(to_mark_read, status="read")
            logging.info(f"Marked {len(to_mark_read)} entries as read")

        # Save state with the max processed entry ID
        max_id = max(e["id"] for e in unread)
        save_state(state_file, {"last_processed_id": max_id})
        logging.info(f"Updated state: last_processed_id={max_id}")

    log_run_summary(
        reference_stats, len(unread), threshold, len(to_mark_read), dry_run
    )
    logging.info("\nCurator run complete.")


if __name__ == "__main__":
    main()
