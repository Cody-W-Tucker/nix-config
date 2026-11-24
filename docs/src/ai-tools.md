# AI tools

Web tools around the local models and Hermes, plus two CLIs on both hosts.

## Web tools

| URL | Use |
| --- | --- |
| [chat.homehub.tv](https://chat.homehub.tv) | Open WebUI: chat with the local models. Attached files (up to 256 MB) become searchable in the chat. |
| [memory.homehub.tv](https://memory.homehub.tv) | Hindsight: browse, edit and delete memories. No sign-in. Agents cannot delete memories; only this page can. |
| [langfuse.homehub.tv](https://langfuse.homehub.tv) | Langfuse: what each agent call sent and received. Shows errors for about a minute after a restart, then recovers. |
| [opencode.homehub.tv](https://opencode.homehub.tv) | OpenCode in the browser. See [AI coding tools](harness.md). |

Hindsight banks: `cody` (you, across everything; Hermes writes here), `codyos` (this configuration), `cognitive-assistant`, and one per other repository. Saving a memory sends its text to a hosted model for fact extraction. Searching stays on the NAS, and lags while the GPU swaps models.

If Langfuse still shows errors after startup, check `journalctl -u docker-langfuse-web -u docker-langfuse-worker` on the NAS.

## Local models

Open WebUI, dictation, Hermes, Karakeep, Paperless-GPT, the feed curator and Hindsight search all use the models on the NAS's graphics card, at `http://nas:8081/v1` (OpenAI-compatible, no key). A model loads on its first request and unloads when idle, so the first answer after a pause takes a few seconds. Models share the card's memory: any that fit stay loaded together, and when a new one needs room the least important go first: OCR, then the chat and vision models, text-to-speech, Laya, embeddings, and speech-to-text last. The 35B, OCR and diarization each need the whole card. `curl -s http://nas:8081/v1/models` lists them; `journalctl -u llama-swap -f` on the NAS shows loads and errors.

If a multimodal GGUF rejects images with `image input is not supported`, check that its matching projector is installed under `/srv/llama-swap/models` and selected in the NAS model configuration.

## Local classifiers

Send a text or JSON input (`state`) to `POST http://nas:8081/v1/systemone` with `model: "laya"`. Vega reads on the graphics card while it is in use and gives the card back after 10 idle minutes or when a more important model needs the room; it then answers on the CPU, much more slowly, until the card has room again. `journalctl -u laya` shows each move. Name a classifier from `modules/ai/llama-swap/_nas-classifiers.nix` with `classifier` (optionally `questions` as a list of its question IDs), or send your own typed `questions` instead. Each answer names its `source`: `vega`, `fallback` (an OpenCode Go decision model, Jev 1.14 by default, answered for review), or `unresolved` (neither was confident). For a fallback, read `label`; the model's raw answer is under `fallback`. Questions Vega is unsure about leave the NAS unless the classifier's `teacher` is `null`.

Both classifiers read one saved bookmark (`title`, `url`, `type`, `summary`) and keep their confident fallback answers as training labels:

| Classifier | Asks |
| --- | --- |
| `service-routing` | Whether the bookmark is worth inspecting for each Agency service ID. |
| `bookmark-kind` | Whether it teaches a method (`method`), is something to install or call (`capability`), and is worth evaluating for CodyOS (`codyos`). |

To confirm labels, pipe JSON (one object, or one per line) with `classifier`, `state` and `gold` for some of its questions to `sudo -u laya laya-feedback` on NAS. `--source imported` loads bulk labels that were not individually checked. A confirmed label overrides an imported one, and both override a fallback answer. Vega trains on fallback labels and holds out the classifier's `calibrateOn` labels to calibrate: confirmed ones by default, confirmed and imported ones for `service-routing`. It can start answering a classifier on its own only after 300 stored inputs, 30 calibration labels and a refit that reaches the precision target. Refits are checked hourly. Between 8 am and 5 pm on weekdays, a refit runs only if it has at most 200 labels Vega hasn't read before; larger ones, such as a first import or a changed question, wait for the evening or the weekend. `journalctl -u laya-train` says which classifiers are waiting. Labels and learned heads stay in `/var/lib/laya`; changing a classifier's question text starts a new set.

## CLIs

| CLI | Use |
| --- | --- |
| `gws` | Gmail, Calendar, Tasks, Contacts. Example: `gws gmail +triage --query 'in:inbox'` |
| `research-state` | Snapshot of what is deployed and recorded, for agents to resume research. Runs only on request. |

## Changing it

| To change | Edit |
| --- | --- |
| Open WebUI | [`open-webui.nix`](../../modules/ai/open-webui.nix) |
| Local models: add, remove, which share the card | [`_nas-models.nix`](../../modules/ai/llama-swap/_nas-models.nix) |
| Hindsight: models, banks, agent tools | [`hindsight.nix`](../../modules/ai/hindsight.nix) |
| Langfuse | [`langfuse/langfuse.nix`](../../modules/ai/langfuse/langfuse.nix) |
| `gws` skills | [`google-workspace.nix`](../../modules/ai/google-workspace.nix) |
| `research-state` | [`research-state.nix`](../../modules/ai/research-state.nix) |
