# Hermes Agent Via Home Manager

This directory is a Home Manager wrapper around
`inputs.hermes-agent.homeManagerModules.default`, imported by
`hosts/nas/default.nix` into `home-manager.users.codyt`.

Treat it like an integration layer, not a standalone app.

The main failure mode is drift between:

- upstream Hermes settings
- local wrapper logic
- mutable state under `${hermesHome}` (user-scoped XDG state)

If a change makes it harder to tell which of those owns the behavior, it is probably the wrong shape.

## Scope

- Hermes is configured only in Home Manager. There is no NixOS system-scope
  instance: no `systemd.services.hermes-*`, no system user, no
  `systemd.tmpfiles.rules` at system level.
- Upstream HM surfaces: `services.hermes-agent.{hermesHome, workingDirectory,
  settings, environment, environmentFiles, documents, hermesHomeFiles,
  mcpServers, gateway.enable, backend.*}`, `systemd.user.services.{hermes-agent,
  hermes-backend}`, `home.activation.hermesAgentSetup`.
- Hermes runs as the login user (codyt). Linger is enabled system-wide by
  `modules/services/opencode/default.nix` (`users.users.codyt.linger`), so the
  user units survive logout.
- State: `hermesHome = ${config.xdg.dataHome}/hermes` (~/.local/share/hermes)
  and `workingDirectory = ${config.xdg.dataHome}/hermes/workspace`. Both are
  created and populated by upstream's `hermes-agent-setup` activation.
  Login shells get the same path via `home.sessionVariables.HERMES_HOME`.

## High-Salience Heuristics

- Keep `default.nix` as the integration spine and keep the main
  `services.hermes-agent = { ... };` block there.
- Do not create local option blocks just to thread constants around. Use plain local values.
- Prefer direct writes into upstream `services.hermes-agent.*` surfaces over local pass-through abstractions.
- Prefer declarative overwrite over residual runtime state. `configFile` is intentionally generated so old `config.yaml` keys do not linger.
- Companion modules must stay user-scoped: `systemd.user.*`
  (`runtime/default.nix`, `secrets/default.nix`), `home.activation.*`
  (`skills/*.nix`), and upstream document surfaces (`documents/default.nix`).
  No root-only constructs (`users.users`, system activation scripts) inside
  this directory.

## Where Changes Go

- `default.nix`: upstream Hermes service settings, imports, top-level assembly
- `runtime/default.nix`: `systemd.user.services.hermes-agent` wiring and user tmpfiles
- `mcp/default.nix`: MCP server wiring
- `secrets/default.nix`: Hermes-owned SOPS secrets, the `hermes-env` /
  `hermes-agent-env` / `hermes-dashboard-env` templates, and the backend's
  dashboard env wiring
- `documents/default.nix`: workspace documents plus SOUL installation via
  `hermesHomeFiles`
- `toolsets/`: platform tool exposure and trust boundaries
- `skills/`: managed vs mutable skill packaging via user activation scripts

## Expensive Mistakes

- If behavior seems to ignore Nix config, inspect upstream's merge rules
  (`configFile` merges Nix settings into on-disk YAML) before assuming the setting is wrong.
- If a change widens filesystem access or tool access, treat that as a trust-boundary change, not a convenience edit.
- Hermes identity comes from `${hermesHome}/SOUL.md`, not from workspace `AGENTS.md`.
- Hermes must see normal files under `${hermesHome}/skills`; malformed local skill dirs can shadow packaged skills and break loading.

## Debugging Order

1. Is this defined in `default.nix` via upstream Hermes settings?
2. Is it coming from runtime wiring under `runtime/`?
3. Is it a user activation under `skills/`?
4. Is mutable state under `${hermesHome}` preserving or shadowing something?
5. Is a toolset narrowing behavior on this surface?
