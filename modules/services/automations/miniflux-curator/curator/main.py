"""Entry point for the Miniflux auto-curator."""

import logging
import os

import miniflux

from .clients import load_state, save_state
from .scoring import (
    get_reference_embeddings,
    log_run_summary,
    score_entries_batch,
)


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
        after_id = batch[-1]["id"]
        logging.info(f"  Fetched {len(unread)} unread entries...")
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

        max_id = max(e["id"] for e in unread)
        save_state(state_file, {"last_processed_id": max_id})
        logging.info(f"Updated state: last_processed_id={max_id}")

    log_run_summary(
        reference_stats, len(unread), threshold, len(to_mark_read), dry_run
    )
    logging.info("\nCurator run complete.")
