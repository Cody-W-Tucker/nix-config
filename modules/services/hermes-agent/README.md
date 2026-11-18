# Hermes Agent

Hermes is the local AI agent service for CodyOS. This directory owns the implementation detail: Home Manager service wiring, SOPS secrets, MCP bridges, document provisioning, skills, and platform toolsets. The service is configured exclusively through `inputs.hermes-agent.homeManagerModules.default` and runs as the login user (codyt).

## Layout

| Path | Role |
| --- | --- |
| `default.nix` | Main service integration and high-level `services.hermes-agent` settings. |
| `plugins/` | Plugin-specific source pins, enablement, settings, and runtime wiring. |
| `runtime/default.nix` | `hermes-agent` systemd **user** service wiring and user-scoped tmpfiles. |
| `secrets/default.nix` | SOPS secret ownership, templates, and agent/dashboard env wiring. |
| `mcp/default.nix` | MCP server registration, including Karakeep and Deja Vu. |
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
  secrets, documents, and plugins into them. Login shells inherit it from
  `home.sessionVariables.HERMES_HOME` (same value as `services.hermes-agent.hermesHome`).
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

Deja Vu exposes local session-history recall through its MCP server, with
`sqlite3` available for database-backed histories. Its index is local to the
NAS; this configuration does not synchronize it with other machines. Recall
can expose the login user's indexed session history to Hermes, and the server
also supports writing remembered notes.

Hermes uses the native Hindsight memory provider, not Hindsight MCP. It points
at the NAS-local server and the `cody` bank. Automatic retain and recall are
disabled; the native tools are available for deliberate use. Holographic
state is not migrated or deleted when the provider changes.

## Documents and identity

`documents/default.nix` provisions the agent's identity and operating contracts from the `cognitive-assistant` input plus local system context.

Provisioned artifacts include:

| Artifact | Target | Purpose |
| --- | --- | --- |
| `SOUL.md` | `${hermesHome}/SOUL.md`, a symlink to the living SOUL, via `services.cognitive-assistant` | Core identity and CodyOS-specific operating rules, plus records learned in use. |
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

Skills use Hermes' documented configuration rather than a custom sync script:

- Upstream's bundled catalog is opted out with the `.no-bundled-skills` marker that `hermes skills opt-out` writes.
- Packs are declared in `codyos.hermes-agent.skills.skillPacks` (`skills/module.nix`):

| Mode | How Hermes gets it | Use it for |
| --- | --- | --- |
| `managed` | Listed in `skills.external_dirs` and read straight from the Nix store. The curator does not edit external skills. | Nix-owned tool skills. |
| `mutable` | Copied once into `${hermesHome}/skills` (`cp --update=none`). The agent and curator can patch the copy; activation never overwrites it. | Skills Hermes should keep learning in. |

- `skills/exclusions.nix` sets `skills.disabled`, which hides skills by name from the index, slash commands and cron. Evaluation warns when a name no longer matches a skill in the Cognitive Assistant or Hermes sources.

Local skills take precedence over `external_dirs`, so a local copy with the same name shadows a managed skill. Upstream changes to a mutable skill do not reach a copy that already exists; delete the local copy to take the new version.

Current packs:

- `cognitive-assistant` (mutable): every Cognitive Assistant skill.
- `hermes-humanizer` (mutable): the upstream humanizer skill.
- `crm-tools` and `google-workspace-tools` (managed): the CRM CLI skill and an allowlist of 11 `gws-*` skills (`skills/business/`). Gmail triage is patched to default to `in:inbox`.
- `knowledge-tools` (managed): the `research-state` skill. QMD search uses the `qmd` MCP server instead of a skill.
- `workflow` (managed): skills from the workflow input.

## Toolsets

Toolsets define platform capability access by interface. The primary CLI has full trust.

Web search is configured through `toolsets/web-search.nix`, currently using xAI for search and Firecrawl for extraction/crawling.
