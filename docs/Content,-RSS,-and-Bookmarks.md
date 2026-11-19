# Content, RSS, and Bookmarks

This section details the content consumption and financial management stack hosted on the server. The architecture integrates standard self-hosted services with a custom AI-driven automation layer for content curation, utilizing local LLM and embedding models.

## Miniflux RSS Reader

Miniflux serves as the primary RSS feed aggregator. It is configured to run on a local port and is exposed via an Nginx reverse proxy at `rss.homehub.tv`.

### Configuration

The service is configured with a cleanup frequency of 48 hours and allows private network integrations to facilitate communication with the `miniflux-curator`[modules/feeds/miniflux.nix](../modules/feeds/miniflux.nix) Admin credentials are managed securely via SOPS templates [modules/feeds/miniflux.nix](../modules/feeds/miniflux.nix)

## Karakeep Bookmark Manager

Karakeep is the central repository for bookmarks and serves as the "reference set" for the AI curation logic. It is tightly integrated with the local AI infrastructure running on the `NAS` host.

### AI Integration

Karakeep utilizes local models via `llama-swap` for several features:

- **Summarization**: Uses `qwen-3.5-4b` for text inference [modules/web/karakeep.nix](../modules/web/karakeep.nix)
- **Embeddings**: Uses `qwen3-embedding-0.6b` for semantic representation [modules/web/karakeep.nix](../modules/web/karakeep.nix)
- **OCR**: Uses the `glm-ocr-f16` multimodal model for extracting text from images [modules/web/karakeep.nix](../modules/web/karakeep.nix)

The service connects to the OpenAI-compatible API provided by `llama-swap` at `http://nas:8081/v1`[modules/web/karakeep.nix](../modules/web/karakeep.nix)

## Miniflux Curator Automation

The `miniflux-curator` is a custom Python-based service that automatically manages the volume of unread articles in Miniflux by scoring them against Karakeep bookmarks using vector similarity.

### Data Flow and Scoring Logic

The curator operates in a pipeline:

1. **Reference Selection**: Fetches recent bookmarks from Karakeep and selects a tag-balanced set [modules/feeds/miniflux-curator.nix](https://github.com/Cody-W-Tucker/miniflux-curator/blob/main/curator/main.py)
2. **Embedding**: Generates embeddings for both the reference bookmarks and unread Miniflux entries using the `qwen3-embedding-0.6b` model [modules/feeds/miniflux.nix](../modules/feeds/miniflux.nix)
3. **Similarity Calculation**: Calculates the `cosine_similarity` between entry vectors and reference vectors [modules/feeds/miniflux-curator.nix](https://github.com/Cody-W-Tucker/miniflux-curator/blob/main/curator/main.py)
4. **Auto-Marking**: Articles with a similarity score below the `autoMarkReadBelow` threshold (default 4.5) are marked as read [modules/feeds/miniflux.nix](../modules/feeds/miniflux.nix)

### Implementation Details

- **State Tracking**: Uses a `state.json` file to track the `last_processed_id`, ensuring it only processes new entries [modules/feeds/miniflux-curator.nix](https://github.com/Cody-W-Tucker/miniflux-curator/blob/main/curator/main.py)
- **Title Normalization**: Implements complex regex logic in `normalize_title` to strip source chrome (e.g., " | The Verge") and extract quoted titles from attribution wrappers [modules/feeds/miniflux-curator.nix](https://github.com/Cody-W-Tucker/miniflux-curator/blob/main/curator/main.py)
- **Systemd Integration**: Runs as a `oneshot` service on a systemd timer (7:15 AM and 11:15 PM) [modules/feeds/miniflux.nix](../modules/feeds/miniflux.nix)

### Logic Flow Diagram

Title: Miniflux Curator Decision Pipeline

```mermaid
flowchart TD
    subgraph subGraph1 ["Logic Flow"]
        A["Fetch Unread Entries"]
        B["Check last_processed_id"]
        C["normalize_title()"]
        D["get_embeddings() via llama-swap"]
        E["cosine_similarity() vs Karakeep Refs"]
        F["Score < autoMarkReadBelow?"]
        G["miniflux.update_entries(status='read')"]
        H["Keep Unread"]
        I["save_state()"]
        subgraph subGraph0 ["Code Entity Space"]
            S["script.nix"]
            CPY["curator.py"]
            ST["state.json"]
        end
    end
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    F --> H
    G --> I
    H --> I
    S --> CPY
    CPY --> ST
```

