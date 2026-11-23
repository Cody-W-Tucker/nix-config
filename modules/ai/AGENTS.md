# AI Services and Clients

- Change NAS-side AI services and inference here. Change the desktop agent harness, shared skills, plugins, and MCP wiring in `modules/harness/`. For Hermes and llama-swap, follow their nested `AGENTS.md` files.
- `opencode.nix` owns the NAS web server (`opencode`) and Beast's clients (`opencode.desktop` and `opencode.remote`). It does not own the shared OpenCode harness.
- `speech-to-text.nix` owns Beast's dictation client; `llama-swap/` owns the NAS inference endpoint it calls.
- When changing an endpoint, check the producer and affected consumers separately. A Den trace shows where each aspect lands; evaluate the relevant settings on both sides to verify they still agree. Claim connectivity only after checking from the consumer.
