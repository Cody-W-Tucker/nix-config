# Hermes Agent

Hermes is the local AI agent service for CodyOS. This directory owns the implementation detail: Home Manager service wiring, SOPS secrets, MCP bridges, document provisioning, skills, and platform toolsets. The service is configured exclusively through `inputs.hermes-agent.homeManagerModules.default` and runs as the login user (codyt).

## Layout

| Path | Role |
| --- | --- |
| `default.nix` | Main service integration and high-level `services.hermes-agent` settings. |
| `runtime/default.nix` | `hermes-agent` systemd **user** service wiring and user-scoped tmpfiles. |
| `secrets/default.nix` | SOPS secret ownership, templates, and agent/dashboard env wiring. |
| `mcp/default.nix` | MCP server registration, currently including Karakeep. |
| `documents/default.nix` | SOUL, human profiles, memory spec, and task spec provisioning. |
| `skills/` | Declarative seeded skill packs and business/knowledge skills. |
| `toolsets/` | Platform toolset access by interface and web-search backend settings. |
| `AGENTS.md` | Agent-facing implementation guidance and failure modes. |

## Runtime model

The Home Manager module turns declarative service settings into a running
`systemd.user.services.hermes-agent` unit.

- The service runs as the login user; there is no system hermes user or group.
- `HERMES_HOME` is user-scoped persistent state at
  `${config.xdg.dataHome}/hermes` (`~/.local/share/hermes`); the agent
  workspace is `${config.xdg.dataHome}/hermes/workspace`. Upstream's
  `hermes-agent-setup` activation creates both and merges configuration,
  secrets, documents, and plugins into them.
- Runtime variables include the local CRM database path
  (`${hermesHome}/crm/crm.db`) and library paths needed for voice/media
  support.
- The dashboard is upstream's `systemd.user.services.hermes-backend` unit in
  `backend.mode = "dashboard"` (host 0.0.0.0, port 9119, `--skip-build`).
- Logout survival is provided by `users.users.codyt.linger = true` in
  `modules/services/opencode/default.nix`.
- Shutdown has an extended grace period (`TimeoutStopSec`) so the agent can
  persist state cleanly.
- State is single-user: upstream applies `UMask = 0077` and user-only modes
  (0600) instead of the group-sharing modes the old system-level install used.

## Secrets

Secrets are SOPS-owned for Hermes inside the Home Manager configuration.

- `secrets/default.nix` declares core agent secrets such as OpenCode, Discord, and Telegram credentials.
- `sops.templates."hermes-env"` aggregates single-value service environment variables into the format Hermes expects.
- The multiline `hermes` secret carries env-named `KEY=value` lines and is rendered verbatim by `sops.templates."hermes-agent-env"`; both templates are listed in `environmentFiles` and merged into `.env` by upstream activation.
- Dashboard credentials travel separately (`hermes-dashboard` → `hermes-dashboard-env`) and are injected into the backend user unit via `EnvironmentFile` so they never land in the agent process environment.
- MCP-specific credentials are referenced by `mcp/default.nix` through the shared env values.

## MCP bridges

MCP servers are registered through `services.hermes-agent.mcpServers`.

Karakeep is the reference implementation, running `@karakeep/mcp` via npx with the shared `KARAKEEP_API_KEY` env value.

## Documents and identity

`documents/default.nix` provisions the agent's identity and operating contracts from the `cognitive-assistant` input plus local system context.

Provisioned artifacts include:

| Artifact | Target | Purpose |
| --- | --- | --- |
| `SOUL.md` | `${hermesHome}/SOUL.md` via `services.hermes-agent.hermesHomeFiles` | Core identity and CodyOS-specific operating rules. |
| `MEMORY-SPEC.md` | Working directory via `documents` | Long-term memory protocol. |
| `TASK-SPEC.md` | Working directory via `documents` | Task decomposition protocol. |
| `human-profiles/EXISTENTIAL-HUMAN-PROFILE.md` | Working directory | High-level user values and goals. |
| `human-profiles/OPERATIONAL-HUMAN-PROFILE.md` | Working directory | Practical user preferences and habits. |

Upstream's `hermes-agent-setup` activation installs these files
(user-owned, 0600) before the user services start. There are no
`system.activationScripts` and no restart triggers under Home Manager; a
changed document or setting applies on the next process restart
(`systemctl --user restart hermes-agent`).

## Skills

Skills are Markdown-based capability packs copied into `${hermesHome}/skills` by Home Manager activation scripts (`home.activation.*`, running as the user).

Two sync modes are supported:

| Mode | Ownership | Use it for |
| --- | --- | --- |
| `managed` | Nix store is the source of truth; the runtime copy is replaced on activation. | Core tools, bundled skills, stable CLI integrations. |
| `mutable` | Runtime copy is created only when missing or malformed. | Agent-local learning and user-pattern skills. |

The seeding script also removes malformed shadow directories that would block proper skill loading.

Current skill groups include:

- Upstream bundled skills such as GitHub workflow/review, planning, arXiv, YouTube content, xurl, and spike.
- Business skills for CRM and Google Workspace; Gmail triage is patched to default to `in:inbox`.
- Knowledge skills for Obsidian Bases, Obsidian CLI, Obsidian Markdown, and `qmd` research workflows.

## Toolsets

Toolsets define platform capability access by interface. The CLI has full trust. API, Discord, Telegram, and cron get narrower sets appropriate to their ambient or automated context.

Web search is configured through `toolsets/web-search.nix`, currently using xAI for search and Firecrawl for extraction/crawling.
