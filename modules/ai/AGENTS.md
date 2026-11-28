# AI Services and Clients

- NAS-side AI services, inference and the agent harness all live here. Change the harness (agents, skills, plugins, MCP wiring) in `harness/`; for Hermes, llama-swap and the harness, follow their nested `AGENTS.md` files.
- A NAS service and its harness client share a directory: `hindsight/server.nix` and `hindsight/client.nix`, `langfuse/langfuse.nix` and `langfuse/client.nix`.
- `harness/opencode.nix` owns all of OpenCode: shared harness settings, the NAS web server (`opencode`) and Beast's clients (`opencode.desktop` and `opencode.remote`).
- `speech-to-text.nix` owns Beast's dictation client; `llama-swap/` owns the NAS inference endpoint it calls.
- When changing an endpoint, check the producer and affected consumers separately. A Den trace shows where each aspect lands; evaluate the relevant settings on both sides to verify they still agree. Claim connectivity only after checking from the consumer.
