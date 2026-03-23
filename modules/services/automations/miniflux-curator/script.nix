{ pkgs, inputs }:

let
  # Use unstable nixpkgs for the miniflux Python package  
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  
  # Python environment with required packages
  pythonEnv = unstablePkgs.python3.withPackages (ps: [
    ps.miniflux
    ps.pyyaml
    ps.numpy
  ]);

  # Python script as a standalone derivation
  curatorPy = pkgs.runCommand "curator.py" { } ''
    cat > $out << 'PYTHON_EOF'
    #!/usr/bin/env python3
    """
    Miniflux Auto-Curator

    Uses vector similarity between starred and unread entries to auto-mark
    low-relevance articles as read. Stars remain human-only.
    """

    import argparse
    import json
    import logging
    import sys
    from datetime import datetime

    import miniflux
    import numpy as np
    import yaml


    def cosine_similarity(a, b):
        """Calculate cosine similarity between two vectors."""
        return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


    def get_ollama_embedding(text, host, model):
        """Get embedding from Ollama API."""
        import urllib.request
        import urllib.error

        data = json.dumps({
            "model": model,
            "prompt": text
        }).encode()

        req = urllib.request.Request(
            f"{host}/api/embeddings",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read().decode())
                return result["embedding"]
        except urllib.error.URLError as e:
            logging.error(f"Failed to get embedding from Ollama: {e}")
            raise


    def get_starred_embeddings(client, ollama_host, embed_model, limit=150):
        """Fetch starred articles and their embeddings."""
        logging.info("Fetching starred articles...")
        starred = client.get_entries(starred=True, limit=limit)["entries"]

        if not starred:
            logging.warning("No starred articles found")
            return []

        logging.info(f"Computing embeddings for {len(starred)} starred articles...")
        starred_embeddings = []

        for i, s in enumerate(starred):
            content = s.get("content", "")
            text = f"{s['title']} {content[:500]}"
            emb = get_ollama_embedding(text, ollama_host, embed_model)
            starred_embeddings.append({
                "id": s["id"],
                "title": s["title"],
                "embedding": emb
            })
            if (i + 1) % 10 == 0:
                logging.info(f"  Processed {i + 1}/{len(starred)} starred articles...")

        return starred_embeddings


    def score_entry(entry, starred_embeddings, ollama_host, embed_model):
        """Score a single entry based on max similarity to any starred article."""
        if not starred_embeddings:
            return 5.0, "No starred articles to compare against"

        title = entry["title"]
        snippet = (entry.get("content") or "")[:600]
        text = f"{title} {snippet}"

        # Get embedding for this entry
        entry_emb = np.array(get_ollama_embedding(text, ollama_host, embed_model))

        # Find max similarity to any starred article
        max_sim = 0.0
        best_match = None

        for starred in starred_embeddings:
            sim = cosine_similarity(entry_emb, np.array(starred["embedding"]))
            if sim > max_sim:
                max_sim = sim
                best_match = starred["title"]

        # Scale to 0-10 for threshold compatibility
        score = round(max_sim * 10, 1)

        # Generate reason based on score
        if score >= 7.0:
            reason = f"Strong match to starred: '{best_match[:50]}...'"
        elif score >= 4.5:
            reason = f"Moderate similarity to starred content"
        else:
            reason = "Low similarity to starred articles"

        return score, reason


    def main():
        parser = argparse.ArgumentParser(description="Miniflux Auto-Curator")
        parser.add_argument("--config", required=True, help="Path to YAML config file")
        args = parser.parse_args()

        # Load config
        with open(args.config) as f:
            config = yaml.safe_load(f)

        logging.basicConfig(
            level=logging.INFO,
            format="%(asctime)s - %(levelname)s - %(message)s"
        )

        # Initialize Miniflux client
        client = miniflux.Client(
            config["miniflux_url"],
            api_key=config["api_key"]
        )

        ollama_host = config["ollama"]["host"]
        embed_model = config["ollama"]["embed_model"]

        # Get starred embeddings
        starred_embeddings = get_starred_embeddings(client, ollama_host, embed_model)

        if not starred_embeddings:
            logging.warning("Cannot proceed without starred articles. Exiting.")
            return

        # Fetch unread entries
        logging.info("Fetching unread entries...")
        unread = []
        offset = 0
        limit_per_batch = 100
        max_total = config.get("limit_unread", 400)

        while len(unread) < max_total:
            batch = client.get_entries(status="unread", limit=limit_per_batch, offset=offset)["entries"]
            if not batch:
                break
            unread.extend(batch)
            offset += limit_per_batch
            logging.info(f"  Fetched {len(unread)} unread entries...")

        if not unread:
            logging.info("No unread entries to process.")
            return

        logging.info(f"Processing {len(unread)} unread entries...")

        # Score each entry
        scored = []
        for i, entry in enumerate(unread):
            score, reason = score_entry(entry, starred_embeddings, ollama_host, embed_model)
            scored.append({
                "id": entry["id"],
                "title": entry["title"],
                "score": score,
                "reason": reason
            })
            if (i + 1) % 10 == 0:
                logging.info(f"  Scored {i + 1}/{len(unread)} entries...")

        # Sort by score descending
        scored.sort(key=lambda x: x["score"], reverse=True)

        # Determine actions
        threshold = config.get("auto_mark_read_below", 3.5)
        dry_run = config.get("dry_run", True)

        to_mark_read = [item["id"] for item in scored if item["score"] < threshold]

        # Log summary
        logging.info("\n=== SUMMARY ===")
        logging.info(f"Total unread processed: {len(unread)}")
        logging.info(f"Starred articles used as reference: {len(starred_embeddings)}")
        logging.info(f"Entries below threshold ({threshold}): {len(to_mark_read)}")
        logging.info(f"High-relevance entries kept: {len(unread) - len(to_mark_read)}")

        if dry_run:
            logging.info("\n=== DRY RUN - No changes made ===")
            logging.info(f"Would mark {len(to_mark_read)} entries as read:")
            for item in scored:
                if item["score"] < threshold:
                    logging.info(f"  - [{item['score']:.1f}] {item['title'][:60]}...")
        else:
            if to_mark_read:
                logging.info(f"Marking {len(to_mark_read)} low-relevance entries as read...")
                client.update_entries(to_mark_read, status="read")
                logging.info(f"Marked {len(to_mark_read)} entries as read")

        logging.info("\nCurator run complete. Stars remain human-only.")


    if __name__ == "__main__":
        main()
    PYTHON_EOF
  '';
in

pkgs.writeShellApplication {
  name = "miniflux-curator";
  runtimeInputs = [
    pythonEnv
    pkgs.curl
  ];
  text = ''
    set -euo pipefail

    # Validate required environment variables
    : "''${MINIFLUX_URL:?MINIFLUX_URL environment variable not set}"
    : "''${MINIFLUX_API_KEY:?MINIFLUX_API_KEY environment variable not set}"
    : "''${OLLAMA_HOST:?OLLAMA_HOST environment variable not set}"

    # Optional config with defaults
    AUTO_MARK_READ_BELOW=''${AUTO_MARK_READ_BELOW:-3.5}
    LIMIT_UNREAD=''${LIMIT_UNREAD:-400}
    DRY_RUN=''${DRY_RUN:-true}
    EMBED_MODEL=''${EMBED_MODEL:-nomic-embed-text}

    # Create temporary config file
    CONFIG_FILE=$(mktemp)
    trap 'rm -f "$CONFIG_FILE"' EXIT

    cat > "$CONFIG_FILE" << EOF
    miniflux_url: "$MINIFLUX_URL"
    api_key: "$MINIFLUX_API_KEY"
    ollama:
      host: "$OLLAMA_HOST"
      embed_model: "$EMBED_MODEL"
    auto_mark_read_below: $AUTO_MARK_READ_BELOW
    limit_unread: $LIMIT_UNREAD
    dry_run: $DRY_RUN
    EOF

    exec ${pythonEnv}/bin/python ${curatorPy} --config "$CONFIG_FILE"
  '';
}
