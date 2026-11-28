# AI Services and Clients

- NAS AI services, local inference and the agent harness live here. Agents, skills, plugins and MCP wiring are in `harness/`.
- A NAS service and its harness client share a directory: `hindsight/server.nix` and `hindsight/client.nix`, `langfuse/langfuse.nix` and `langfuse/client.nix`.
- `harness/opencode.nix` owns all of OpenCode: shared harness settings, the NAS web server (`opencode.web`) and Beast's clients (`opencode.desktop` and `opencode.remote`).
- Dictation follows the same pattern: `llama-swap/dictation.nix` is Beast's `llama-dictate` client of the NAS endpoint and speech history beside it.
- When changing an endpoint, evaluate the setting on the producer and on each consumer and confirm they agree. Claim connectivity only after checking from the consumer.
