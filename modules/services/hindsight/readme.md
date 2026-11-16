# Hindsight

The NAS runs the pinned `llm-agents` Hindsight API and control plane on
`127.0.0.1:8888` and `127.0.0.1:9999`. Both are unauthenticated. Local users
can read and modify the memory banks. The multi-bank MCP endpoint and the
`POST /v1/default/banks/<bank>/memories` retain route are also available to Beast's Tailscale
address on port 18083, restricted by firewall and nginx source address, with no
application authentication. Other API routes and the UI remain loopback-only.

Hermes uses the native Hindsight provider with `cody` as its primary bank, with
automatic retain and recall enabled (`hybrid` mode). The native provider's
tools do not accept a bank parameter, so project-bank routing for Hermes is not
configured.

OpenCode and Claude Code use the multi-bank MCP endpoint for on-demand recall,
and auto-retain conversation text after turns through
`users/cody/harness/plugins/hindsight`:

- `/etc/nixos` retains to `codyos`
- `~/Projects/Cognitive-Assistant` retains to `cognitive-assistant`
- Other repositories retain to a bank named after their git root directory

Tool call output is excluded from auto-retain, but user and assistant prose can
still contain sensitive information. Do not paste credentials into chat. Set
`HINDSIGHT_AUTO_RETAIN=false` before launching either coding harness to disable
automatic writes for a session. Retained text is sent to the configured remote
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
