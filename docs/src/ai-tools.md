# AI tools

Web tools around the local models and Hermes, plus one CLI on both hosts.

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

Open WebUI, dictation, Hermes, Karakeep, Paperless-GPT, the feed curator and Hindsight search use the models on the NAS at `http://nas:8081/v1` (OpenAI-compatible, no key). A model loads on request, so the first answer after a pause can take longer. Embeddings can stay loaded when you switch between 4B summarization and dictation. The 35B, OCR and diarization each make the other models unload. The [llama-swap web UI](http://nas:8081/) shows running models, and `journalctl -u llama-swap -f` shows loads and errors.

The 4B, 9B, embedding, OCR and dictation cleanup models need enough GPU memory for all their layers. If there is not enough room, they can fail to load instead of running partly on the CPU. The 35B can use both GPU and CPU memory.

If a multimodal GGUF rejects images with `image input is not supported`, check that the model sets its matching projector in `_models.nix`.

## Local classifiers

Send a text or JSON input (`state`) to `POST http://nas:8081/v1/systemone` with `model: "laya"`. Vega runs on the CPU alongside the other models. `journalctl -u laya` shows errors. Name a classifier from `modules/ai/llama-swap/_classifiers.nix` with `classifier` (optionally `questions` as a list of its question IDs), or send your own typed `questions` instead. Each answer names its `source`: `vega`, `fallback` (an OpenCode Go decision model, Jev 1.14 by default, answered for review), or `unresolved` (neither was confident). For a fallback, read `label`; the model's raw answer is under `fallback`. Questions Vega is unsure about leave the NAS unless the classifier's `teacher` is `null`.

In the llama-swap web UI, look for **Vega (Laya CPU worker)** in the running models. `laya` remains the request name for classifiers; its peer entry does not show worker residency.

The `bookmark-route` classifier reads one saved bookmark (`title`, `url`, `type`, `summary`) and asks two independent questions: `route`, the single Agency service ID or `none` it is most worth inspecting for, and `codyos`, yes or no for whether CodyOS could adopt or adapt something specific from it. Vega answers each question or sends it to Jev, and Jev's confident answers are kept as training labels.

To confirm labels, pipe JSON (one object, or one per line) with `classifier`, `state` and `gold` to `sudo -u laya laya-feedback` on the NAS. `--source imported` loads bulk labels that were not individually checked. A confirmed label overrides an imported one, and both override a fallback answer. Your edits to bookmark lists also become confirmed labels (see [sorted bookmarks](feeds-and-bookmarks.md#sorted-bookmarks)). Labels and learned heads stay in `/var/lib/laya`; changing a classifier's question text starts a new set. Labels are backed up. Learned heads are not, because the refit rebuilds them from the labels.

At 1 a.m. NAS time, Laya refits on the CPU while local models keep serving. Laya keeps answering while the refit runs. The refit has a 45-minute limit. If the refit fails or does not pass validation, Laya keeps the last published classifier. See `journalctl -u laya-train` for the result.

## CLIs

| CLI | Use |
| --- | --- |
| `gws` | Gmail, Calendar, Tasks, Contacts. Example: `gws gmail +triage --query 'in:inbox'` |

## Changing it

| To change | Edit |
| --- | --- |
| Open WebUI | [`open-webui.nix`](../../modules/ai/open-webui.nix) |
| Local models: add, remove, tune | [`_models.nix`](../../modules/ai/llama-swap/_models.nix) |
| Which models share the card | [`llama-swap.nix`](../../modules/ai/llama-swap/llama-swap.nix) |
| Hindsight: models, banks, agent tools | [`hindsight.nix`](../../modules/ai/hindsight.nix) |
| Langfuse | [`langfuse/langfuse.nix`](../../modules/ai/langfuse/langfuse.nix) |
| `gws` skills | [`google-workspace.nix`](../../modules/ai/google-workspace.nix) |
