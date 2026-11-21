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

Open WebUI, dictation, Hermes, Karakeep, Paperless-GPT, the feed curator and Hindsight search all use the models on the NAS's graphics card, at `http://nas:8081/v1` (OpenAI-compatible, no key). A model loads on its first request and unloads when idle, so the first answer after a pause takes a few seconds. `curl -s http://nas:8081/v1/models` lists them; `journalctl -u llama-swap -f` on the NAS shows loads and errors.

If a multimodal GGUF rejects images with `image input is not supported`, check that its matching projector is installed under `/srv/llama-swap/models` and selected in the NAS model configuration.

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
