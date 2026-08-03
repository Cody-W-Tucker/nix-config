"""HTTP clients and state-file I/O for the Miniflux curator.

Owns the embedding API calls, Karakeep bookmark fetch, and the
last-processed-ID state persistence. Keeps network/persistence
concerns out of the scoring and title modules.
"""

import json
import logging
import os
import urllib.error
import urllib.parse
import urllib.request


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
        os.makedirs(os.path.dirname(state_file), exist_ok=True)
        with open(state_file, 'w') as f:
            json.dump(state, f)
    except IOError as e:
        logging.error(f"Could not save state file: {e}")


def cosine_similarity(a, b):
    """Calculate cosine similarity between two vectors."""
    import numpy as np
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


def get_embeddings(texts, host, model):
    """Get embeddings for multiple texts via OpenAI-compatible API (batch)."""
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
            return [item["embedding"] for item in result["data"]]
    except urllib.error.URLError as e:
        logging.error(f"Failed to get embeddings: {e}")
        raise


def get_embedding(text, host, model):
    """Get embedding for a single text (convenience wrapper)."""
    return get_embeddings([text], host, model)[0]


def _karakeep_get(base_url, api_key, path, params, timeout=60):
    """Issue an authenticated GET and return parsed JSON."""
    query = urllib.parse.urlencode(params)
    url = f"{base_url}{path}?{query}"
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {api_key}"},
        method="GET"
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode())


def _resolve_karakeep_tag_id(base_url, api_key, tag_name):
    """Resolve a Karakeep tag id by exact name. Returns None if absent."""
    params = {"nameContains": tag_name}
    try:
        result = _karakeep_get(base_url, api_key, "/api/v1/tags", params)
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        logging.error(f"Failed to fetch Karakeep tags: {e}")
        return None

    for tag in result.get("tags") or []:
        if tag.get("name") == tag_name:
            return tag.get("id")
    return None


def get_karakeep_bookmarks(host, api_key, limit=100, tag_name="miniflux"):
    """Fetch saved bookmarks from Karakeep tagged with `tag_name` (exact match).

    Uses cursor pagination against the per-tag bookmarks endpoint.
    Returns an empty list if the tag is missing or on fetch errors,
    consistent with the rest of the client's error handling.
    """
    logging.info(f"Fetching Karakeep bookmarks tagged '{tag_name}'...")
    base_url = host.rstrip("/")

    tag_id = _resolve_karakeep_tag_id(base_url, api_key, tag_name)
    if tag_id is None:
        logging.info(f"Karakeep tag '{tag_name}' not found; no candidates")
        return []

    bookmarks = []
    cursor = None

    try:
        while len(bookmarks) < limit:
            page_limit = min(100, limit - len(bookmarks))
            params = {"limit": page_limit}
            if cursor:
                params["cursor"] = cursor

            result = _karakeep_get(
                base_url, api_key,
                f"/api/v1/tags/{tag_id}/bookmarks",
                params,
            )

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
