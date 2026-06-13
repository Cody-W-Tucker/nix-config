# Hermes Agent Via NixOS

This directory is a NixOS wrapper around `inputs.hermes-agent.nixosModules.default`.

Treat it like an integration layer, not a standalone app.

The main failure mode is drift between:

- upstream Hermes settings
- local wrapper logic
- runtime patching in `package/patches/`
- mutable state under `${stateDir}/.hermes`

If a change makes it harder to tell which of those owns the behavior, it is probably the wrong shape.

## High-Salience Heuristics

- Keep `default.nix` as the integration spine and keep the main `services.hermes-agent = { ... };` block there.
- Do not create local option blocks just to thread constants around. Use plain local values.
- Prefer direct writes into upstream `services.hermes-agent.*` surfaces over local pass-through abstractions.
- Prefer declarative overwrite over residual runtime state. `configFile` is intentionally generated so old `config.yaml` keys do not linger.

## Where Changes Go

- `default.nix`: upstream Hermes service settings, imports, top-level assembly
- `package/default.nix`: package selection, Python override assembly, wrapper behavior
- `package/patches/`: patched upstream Python behavior when Nix options cannot reach it
- `runtime/default.nix`: main Hermes service runtime wiring
- `runtime/filesystem-access.nix`: writable roots, ACLs, state repair
- `runtime/cron-tick.nix`: scheduled Hermes execution
- `mcp/default.nix`: MCP server wiring and MCP-specific secret-backed wrappers
- `secrets/default.nix`: Hermes-owned SOPS secrets and `hermes-env`
- `documents/default.nix`: workspace docs plus SOUL installation/restart trigger
- `toolsets/`: platform tool exposure and trust boundaries
- `skills/`: managed vs mutable skill packaging

## Expensive Mistakes

- If behavior seems to ignore Nix config, inspect `package/patches/` before assuming the setting is wrong.
- If a change widens filesystem access or tool access, treat that as a trust-boundary change, not a convenience edit.
- Hermes identity comes from `${stateDir}/.hermes/SOUL.md`, not from workspace `AGENTS.md`.
- Hermes must see normal files under `${stateDir}/.hermes/skills`; malformed local skill dirs can shadow packaged skills and break loading.

## Debugging Order

1. Is this defined in `default.nix` via upstream Hermes settings?
2. Is it coming from runtime wiring under `runtime/`?
3. Is it coming from patched code in `package/patches/`?
4. Is mutable state under `${stateDir}/.hermes` preserving or shadowing something?
5. Is a toolset narrowing behavior on this surface?
