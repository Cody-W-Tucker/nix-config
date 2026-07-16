# Hermes Agent

Hermes is the local AI agent service for CodyOS. This directory owns the implementation detail: package wrapping, systemd runtime, SOPS secrets, MCP bridges, document provisioning, skills, and platform toolsets.

## Layout

| Path | Role |
| --- | --- |
| `default.nix` | Main service integration and high-level `services.hermes-agent` settings. |
| `package/default.nix` | Upstream package build, local patches, and CLI/desktop wrappers. |
| `runtime/default.nix` | `hermes-agent` systemd service, environment, restart triggers, and runtime paths. |

| `secrets/default.nix` | SOPS secret ownership and the aggregated `hermes-env` template. |
| `mcp/default.nix` | Secret-wrapped MCP server commands, currently including Karakeep. |
| `documents/default.nix` | SOUL, human profiles, memory spec, and task spec provisioning. |
| `skills/` | Declarative seeded skill packs and business/knowledge skills. |
| `toolsets/` | Platform toolset access by interface and web-search backend settings. |
| `AGENTS.md` | Agent-facing implementation guidance and failure modes. |

## Runtime model

The Nix module turns declarative service settings into a running `hermes-agent` systemd service.

- The service runs as the Hermes service user/group and uses a managed state directory.
- `HERMES_HOME` is under the service state directory so identity, auth, logs, and mutable runtime state do not drift into an operator shell by accident.
- Runtime variables include the local CRM database path and library paths needed for voice/media support.
- The service restarts when serialized settings or provisioned identity documents change.
- `UMask = "0007"` keeps service-created state group-accessible.
- Shutdown has an extended grace period so the agent can persist state cleanly.


## Package and wrappers

`package/default.nix` wraps the upstream `inputs.hermes-agent` flake for this system.

Local patches are intentional:

- Hermes-created auth/home state is group-readable and group-writable where needed.
- The Electron desktop build gets Linux titlebar behavior expected by this desktop.

The package exposes two operator entry points:

- `hermes-desktop` starts the Electron UI with the managed `HERMES_HOME`.
- `hermes` is the normal CLI wrapper; `hermes desktop` and `hermes gui` delegate to the desktop wrapper.

## Secrets

Secrets are SOPS-owned for the Hermes service.

- `secrets/default.nix` declares core agent secrets such as OpenCode, Firecrawl, Discord, and Telegram credentials.
- `sops.templates."hermes-env"` aggregates service environment variables into the format Hermes expects.
- MCP-specific credentials stay near their bridge. For Karakeep, `mcp/default.nix` reads the SOPS secret at runtime and exports it before starting the MCP server.

## MCP bridges

MCP servers are registered through `services.hermes-agent.mcpServers`.

The current pattern is:

1. Declare the SOPS secret for the external service.
2. Create a small wrapper command with `writeShellApplication`.
3. Read the secret from the SOPS path at execution time.
4. Export the provider-specific environment variables.
5. Register the wrapper command as the MCP server command.

Karakeep is the reference implementation for this pattern.

## Documents and identity

`documents/default.nix` provisions the agent's identity and operating contracts from the `cognitive-assistant` input plus local system context.

Provisioned artifacts include:

| Artifact | Target | Purpose |
| --- | --- | --- |
| `SOUL.md` | `${stateDir}/.hermes/SOUL.md` | Core identity and CodyOS-specific operating rules. |
| `MEMORY-SPEC.md` | Working directory | Long-term memory protocol. |
| `TASK-SPEC.md` | Working directory | Task decomposition protocol. |
| `EXISTENTIAL-HUMAN-PROFILE.md` | `human-profiles/` | High-level user values and goals. |
| `OPERATIONAL-HUMAN-PROFILE.md` | `human-profiles/` | Practical user preferences and habits. |

Activation scripts install these files before the service starts, and restart triggers keep the running agent aligned with changes.

## Skills

Skills are Markdown-based capability packs copied into `HERMES_HOME/skills` during activation.

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
