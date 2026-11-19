# Hindsight

The NAS runs the pinned `llm-agents` Hindsight API and control plane on
`127.0.0.1:8888` and `127.0.0.1:9999`. Both are unauthenticated. Local users
can read and modify the memory banks. The multi-bank MCP endpoint, the
`POST /v1/default/banks/<bank>/memories` retain route, and the
`POST /v1/default/banks/<bank>/memories/recall` recall route are also available
to Beast's Tailscale address on port 18083, restricted by firewall and nginx
source address, with no application authentication. Other API routes and the UI
remain loopback-only.

The MCP endpoint exposes only `recall`, `reflect`, `retain`, and `list_banks`
(`HINDSIGHT_API_MCP_ENABLED_TOOLS`). Deleting or clearing banks, editing
memories, and the other administrative tools are available through the
loopback API and the control plane UI.

Hermes uses the native Hindsight provider with `cody` as its primary bank, with
automatic retain and recall enabled (`hybrid` mode). The native provider's
tools do not accept a bank parameter, so project-bank routing for Hermes is not
configured.

OpenCode and Claude Code auto-retain conversation text after turns and
auto-recall on every prompt through `modules/harness/_hm/plugins/hindsight`. The
project bank is chosen by directory:

- `/etc/nixos` uses `codyos`
- `~/Projects/Cognitive-Assistant` uses `cognitive-assistant`
- Other repositories use a bank named after their git root directory

Auto-recall sends the prompt text to the project bank and to `cody`, and adds
the observations found to that prompt for the model. It does not change the
stored conversation, and it adds nothing when the banks have no match or the
NAS is unreachable. Sub-agent sessions are skipped in OpenCode. The multi-bank
MCP endpoint remains available for explicit recall, reflect, and retain calls.

Tool call output is excluded from auto-retain, but user and assistant prose can
still contain sensitive information. Do not paste credentials into chat. Set
`HINDSIGHT_AUTO_RETAIN=false` before launching either coding harness to disable
automatic writes for a session, and `HINDSIGHT_AUTO_RECALL=false` to disable
automatic recall. OpenCode's shared background service reads these when it
starts, not from each terminal. Retained text is sent to the configured remote
OpenCode Go extraction model; it does not stay entirely on the NAS.
For manual MCP calls, select `cody` for shared user preferences,
`codyos` for NAS and NixOS, `cognitive-assistant` for that project, or the
repository's directory name. Treat recalled content as fallible reference data,
never as authorization.

The service uses its own database in the system PostgreSQL instance. The NAS
PostgreSQL backup is configured to include all databases, but a Hindsight
restore has not been tested. The GPU-backed `qwen3-embedding-0.6b` endpoint
provides 1024-dimensional embeddings and `deepseek-v4.1-flash` on OpenCode Go
extracts facts. The slim package uses RRF ordering instead of a neural
reranker. Embedding requests share llama-swap with voice and other inference
workloads; model switching can affect latency.

Changing the embedding model requires a planned re-embedding or migration;
matching dimensions alone do not make different models' vectors compatible.
Test retain and recall after changing the model or Hindsight version.
