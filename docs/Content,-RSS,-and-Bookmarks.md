# Content, RSS, and Bookmarks
Relevant source files
- [modules/server/actual-budget.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/actual-budget.nix)
- [modules/server/content.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix)
- [modules/server/karakeep.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/karakeep.nix)
- [modules/services/automations/miniflux-curator/curator.py](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/curator.py)
- [modules/services/automations/miniflux-curator/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/default.nix)
- [modules/services/automations/miniflux-curator/script.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/script.nix)
- [modules/services/llama-swap/default.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/llama-swap/default.nix)
- [modules/services/llama-swap/models.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/llama-swap/models.nix)
- [modules/system/fonts.nix](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/system/fonts.nix)

This section details the content consumption and financial management stack hosted on the server. The architecture integrates standard self-hosted services with a custom AI-driven automation layer for content curation, utilizing local LLM and embedding models.

## Miniflux RSS Reader

Miniflux serves as the primary RSS feed aggregator. It is configured to run on a local port and is exposed via an Nginx reverse proxy at `rss.homehub.tv`.

### Configuration

The service is configured with a cleanup frequency of 48 hours and allows private network integrations to facilitate communication with the `miniflux-curator`[modules/server/content.nix30-37](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L30-L37) Admin credentials are managed securely via SOPS templates [modules/server/content.nix22-26](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L22-L26)

### Sources:

- [modules/server/content.nix29-39](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L29-L39)
- [modules/server/content.nix59-66](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L59-L66)

## Karakeep Bookmark Manager

Karakeep is the central repository for bookmarks and serves as the "reference set" for the AI curation logic. It is tightly integrated with the local AI infrastructure running on the `beast` host.

### AI Integration

Karakeep utilizes local models via `llama-swap` for several features:

- **Summarization**: Uses `qwen3.5-4b` for text inference [modules/server/karakeep.nix12](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/karakeep.nix#L12-L12)
- **Embeddings**: Uses `qwen3-embedding-0.6b` for semantic representation [modules/server/karakeep.nix17](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/karakeep.nix#L17-L17)
- **OCR**: Uses the `glm-ocr-f16` multimodal model for extracting text from images [modules/server/karakeep.nix16](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/karakeep.nix#L16-L16)

The service connects to the OpenAI-compatible API provided by `llama-swap` at `http://beast:8081/v1`[modules/server/karakeep.nix11](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/karakeep.nix#L11-L11)

### Sources:

- [modules/server/karakeep.nix1-24](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/karakeep.nix#L1-L24)
- [modules/services/llama-swap/models.nix33-46](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/llama-swap/models.nix#L33-L46) (Embedding model spec)
- [modules/services/llama-swap/models.nix56-65](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/llama-swap/models.nix#L56-L65) (OCR model spec)

## Miniflux Curator Automation

The `miniflux-curator` is a custom Python-based service that automatically manages the volume of unread articles in Miniflux by scoring them against Karakeep bookmarks using vector similarity.

### Data Flow and Scoring Logic

The curator operates in a pipeline:

1. **Reference Selection**: Fetches recent bookmarks from Karakeep and selects a tag-balanced set [modules/services/automations/miniflux-curator/curator.py243](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/curator.py#L243-L243)
2. **Embedding**: Generates embeddings for both the reference bookmarks and unread Miniflux entries using the `qwen3-embedding-0.6b` model [modules/server/content.nix49](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L49-L49)
3. **Similarity Calculation**: Calculates the `cosine_similarity` between entry vectors and reference vectors [modules/services/automations/miniflux-curator/curator.py57-59](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/curator.py#L57-L59)
4. **Auto-Marking**: Articles with a similarity score below the `autoMarkReadBelow` threshold (default 4.5) are marked as read [modules/server/content.nix50](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L50-L50)

### Implementation Details

- **State Tracking**: Uses a `state.json` file to track the `last_processed_id`, ensuring it only processes new entries [modules/services/automations/miniflux-curator/curator.py35-56](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/curator.py#L35-L56)
- **Title Normalization**: Implements complex regex logic in `normalize_title` to strip source chrome (e.g., " | The Verge") and extract quoted titles from attribution wrappers [modules/services/automations/miniflux-curator/curator.py94-179](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/curator.py#L94-L179)
- **Systemd Integration**: Runs as a `oneshot` service on a systemd timer (7:15 AM and 11:15 PM) [modules/server/content.nix56](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L56-L56)

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

### Sources:

- [modules/services/automations/miniflux-curator/default.nix1-140](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/default.nix#L1-L140)
- [modules/services/automations/miniflux-curator/curator.py1-243](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/curator.py#L1-L243)
- [modules/services/automations/miniflux-curator/script.nix1-42](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/automations/miniflux-curator/script.nix#L1-L42)

## System Integration

The following diagram illustrates how the content services interact across the server and the AI inference host (`beast`).

Title: Content and AI Infrastructure Mapping

```mermaid
flowchart LR
    subgraph subGraph1 ["Beast (AI Inference)"]
        LS["llama-swap.service"]
        EMB["qwen3-embedding-0.6b"]
        LLM["qwen3.5-4b"]
        OCR["glm-ocr-f16"]
    end
    subgraph subGraph0 ["Server (homehub.tv)"]
        MF["miniflux service"]
        KK["karakeep service"]
        CUR["miniflux-curator.service"]
        NG["nginx virtualHosts"]
    end
    CUR --> MF
    CUR --> KK
    CUR --> LS
    KK --> LS
    LS --> EMB
    LS --> LLM
    LS --> OCR
    NG --> MF
    NG --> KK
```

### Sources:

- [modules/server/content.nix42-57](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/content.nix#L42-L57) (Curator config)
- [modules/server/karakeep.nix10-17](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/karakeep.nix#L10-L17) (Karakeep model routing)
- [modules/services/llama-swap/default.nix128-162](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/services/llama-swap/default.nix#L128-L162) (Model command generation)

## ActualBudget

The `actual` service provides personal finance management. It is configured to run on port 5006 and is proxied through `budget.homehub.tv`.

### Configuration

The service has `openFirewall` enabled to allow local network synchronization [modules/server/actual-budget.nix15](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/actual-budget.nix#L15-L15) It utilizes the standard NixOS service module for Actual Budget.

### Sources:

- [modules/server/actual-budget.nix1-20](https://github.com/Cody-W-Tucker/nix-config/blob/5a76c557/modules/server/actual-budget.nix#L1-L20)