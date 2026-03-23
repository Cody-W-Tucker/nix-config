# Miniflux Auto-Curator
# Uses vector similarity between starred and unread entries to auto-mark
# low-relevance articles as read. Stars remain human-only.

import json
import logging
import os

import miniflux
import numpy as np


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


def get_starred_embeddings(
    client, embed_host, embed_model, limit=150, batch_size=64
):
    """Fetch starred articles and compute embeddings in batches."""
    logging.info("Fetching starred articles...")
    starred = client.get_entries(starred=True, limit=limit)["entries"]

    if not starred:
        logging.warning("No starred articles found")
        return []

    logging.info(
        f"Computing embeddings for {len(starred)} starred articles "
        f"(batch_size={batch_size})..."
    )
    starred_embeddings = []

    # Process in batches
    for i in range(0, len(starred), batch_size):
        batch = starred[i:i + batch_size]
        texts = [
            f"{a['title']} {(a.get('content') or '')[:500]}"
            for a in batch
        ]

        try:
            embeddings = get_embeddings(texts, embed_host, embed_model)
            for article, emb in zip(batch, embeddings):
                starred_embeddings.append({
                    "id": article["id"],
                    "title": article["title"],
                    "embedding": emb
                })
            processed = min(i + batch_size, len(starred))
            logging.info(
                f"  Processed {processed}/{len(starred)} starred articles..."
            )
        except Exception as e:
            logging.error(f"Failed to process batch of starred articles: {e}")

    return starred_embeddings


def score_entries_batch(
    entries, starred_embeddings, embed_host, embed_model, batch_size=64
):
    """Score multiple entries based on similarity to starred articles."""
    if not starred_embeddings:
        return [
            (entry["id"], entry["title"], 5.0,
             "No starred articles to compare against")
            for entry in entries
        ]

    # Prepare all texts and get embeddings in batch
    texts = []
    for entry in entries:
        title = entry["title"]
        snippet = (entry.get("content") or "")[:600]
        texts.append(f"{title} {snippet}")

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

    # Score each entry against starred embeddings
    scored = []
    for entry, entry_emb in zip(entries, all_embeddings):
        if entry_emb is None:
            scored.append((
                entry["id"], entry["title"], 5.0, "Failed to get embedding"
            ))
            continue

        entry_emb_array = np.array(entry_emb)
        max_sim = 0.0
        best_match = None

        for starred in starred_embeddings:
            sim = cosine_similarity(
                entry_emb_array, np.array(starred["embedding"])
            )
            if sim > max_sim:
                max_sim = sim
                best_match = starred["title"]

        # Scale to 0-10 for threshold compatibility
        score = round(max_sim * 10, 1)

        # Generate reason based on score
        if score >= 7.0 and best_match is not None:
            reason = f"Strong match to starred: '{best_match[:50]}...'"
        elif score >= 4.5:
            reason = "Moderate similarity to starred content"
        else:
            reason = "Low similarity to starred articles"

        scored.append((entry["id"], entry["title"], score, reason))

    return scored


def main():
    logging.basicConfig(
        level=logging.WARNING,
        format="%(asctime)s - %(levelname)s - %(message)s"
    )

    # Read configuration from environment variables
    miniflux_url = os.environ.get("MINIFLUX_URL")
    api_key = os.environ.get("MINIFLUX_API_KEY")
    embed_host = os.environ.get("OPENAI_HOST")
    embed_model = os.environ.get("EMBED_MODEL", "qwen3-embedding-8b")
    batch_size = int(os.environ.get("BATCH_SIZE", "64"))
    auto_mark_read_below = float(os.environ.get("AUTO_MARK_READ_BELOW", "3.5"))
    limit_unread = int(os.environ.get("LIMIT_UNREAD", "400"))
    dry_run = os.environ.get("DRY_RUN", "true").lower() == "true"

    # Validate required environment variables
    if not miniflux_url:
        logging.error("MINIFLUX_URL environment variable not set")
        return
    if not api_key:
        logging.error("MINIFLUX_API_KEY environment variable not set")
        return
    if not embed_host:
        logging.error("OPENAI_HOST environment variable not set")
        return

    # Initialize Miniflux client
    client = miniflux.Client(miniflux_url, api_key=api_key)

    # Get starred embeddings
    starred_embeddings = get_starred_embeddings(
        client, embed_host, embed_model, batch_size=batch_size
    )

    if not starred_embeddings:
        logging.warning("Cannot proceed without starred articles. Exiting.")
        return

    # Fetch unread entries (newest first)
    logging.info("Fetching unread entries (newest first)...")
    unread = []
    offset = 0
    limit_per_batch = 100
    max_total = limit_unread

    while len(unread) < max_total:
        batch = client.get_entries(
            status="unread", limit=limit_per_batch, offset=offset,
            order="published_at", direction="desc"
        )["entries"]
        if not batch:
            break
        unread.extend(batch)
        offset += limit_per_batch
        logging.info(f"  Fetched {len(unread)} unread entries...")

    if not unread:
        logging.info("No unread entries to process.")
        return

    logging.info(
        f"Processing {len(unread)} unread entries (batch_size={batch_size})..."
    )

    # Score all entries in batches
    scored_results = score_entries_batch(
        unread, starred_embeddings, embed_host, embed_model, batch_size
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
        f"Starred articles used as reference: {len(starred_embeddings)}"
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
    else:
        if to_mark_read:
            logging.info(
                f"Marking {len(to_mark_read)} low-relevance entries as read..."
            )
            client.update_entries(to_mark_read, status="read")
            logging.info(f"Marked {len(to_mark_read)} entries as read")

    logging.info("\nCurator run complete. Stars remain human-only.")


if __name__ == "__main__":
    main()
