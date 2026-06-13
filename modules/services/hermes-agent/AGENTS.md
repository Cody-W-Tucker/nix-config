# Hermes Agent Via NixOS

This directory is a NixOS wrapper around `inputs.hermes-agent.nixosModules.default`.

Treat it like an integration layer, not a standalone app. Most good changes here either:

- route a behavior to the right existing module
- tighten a trust boundary
- make mutable Hermes state line up with declarative Nix intent

The main failure mode is drift between four sources of behavior:

- upstream Hermes settings
- local Nix wrapper logic
- runtime patching in `patches/`
- mutable state under `${stateDir}/.hermes`

If a change makes it harder to tell which of those owns the behavior, it is probably the wrong shape.

## Start Here

Start in `default.nix`.

That file does three important jobs:

- imports the local integration modules
- defines the service-level Hermes settings
- overrides the upstream package to apply local Python runtime patches

If a request seems isolated but touches auth, state, cron, skills, or tool access, assume it crosses module boundaries until proven otherwise.

## Routing Heuristics

If the request is about where a change belongs, use these first.

### When To Change `default.nix`

Edit `default.nix` when the change affects:

- upstream Hermes module settings
- service environment or package inputs
- the generated `configFile`
- documents written into Hermes home
- package override behavior in `$out/share/hermes-agent/python-overrides`

Do not hide service-wide behavior in a leaf module if `default.nix` is the real integration point.

### When To Change `filesystem-access.nix`

Edit `filesystem-access.nix` when the change affects:

- what Hermes can write to
- ACLs, ownership, or group-sharing behavior
- activation-time fixes under `${stateDir}/.hermes`
- the allowed shared roots from `codyos.hermes-agent.locations`

Default stance: Hermes should write to its state tree and the configured shared roots only. Any widening should feel exceptional.

### When To Change `hermes-mcp.nix`

Edit `hermes-mcp.nix` when the change affects:

- MCP server declarations
- wrapped integration commands
- secret-backed environment wiring for MCP tools

If a new integration needs credentials, the normal shape is both:

- a SOPS secret declaration
- wrapped command wiring that reads that secret

### When To Change `cron-wake.nix`

Edit `cron-wake.nix` when the change affects:

- scheduled Hermes execution
- wake timers
- cron-specific environment behavior

Remember: the main service unsets `MESSAGING_CWD`; only the cron tick unit injects it.

### When To Change `toolsets/`

Edit `toolsets/` when the change affects:

- which capabilities each platform gets
- trust differences between CLI, API server, Telegram, Discord, and cron
- search or web-tool backend wiring

Hermes uses `services.hermes-agent.settings.platform_toolsets`, not a top-level `toolsets` key.

Preserve asymmetry by default. Broad surfaces should be chosen, not accidental.

### When To Change `skills/`

Edit `skills/module.nix` or the relevant `skills/` subtree when the change affects:

- what skill packs are seeded or managed
- whether a skill is mutable or Nix-managed
- disabled skill lists
- local Hermes skill content shipped from this repo

If a skill advertises a tool or runtime that Hermes cannot execute, the change is incomplete. Check `services.hermes-agent.extraPackages` too.

### When To Change `patches/`

Edit `patches/` when the runtime behavior is coming from patched Python sources rather than Nix module options.

This is especially likely for:

- auth behavior
- shared-home semantics
- upstream code paths that Nix options cannot reach

If you are debugging behavior that seems to ignore Nix config, inspect `patches/` before assuming the setting is wrong.

## Decision Heuristics

### Prefer Declarative Over Residual Runtime State

`services.hermes-agent.configFile` is intentionally always generated so activation overwrites upstream `config.yaml`.

If an approach depends on Hermes preserving old runtime keys, it is usually working against the local design.

### Prefer Narrow Trust Boundaries

Discord and cron are intentionally narrower than API server, CLI, and Telegram.

If a change widens filesystem access or tool access, ask whether the surface has earned it.

### Prefer One Owner Per Behavior

If a behavior can be described clearly as:

- service config
- filesystem/state policy
- MCP integration wiring
- skill packaging
- runtime patching

then keep the change in that owner instead of splitting it across layers.

### Prefer Managed Skills For Stable Shared Behavior

If the skill should be reproducible from Nix every activation, it should usually be managed.

If the point is to allow local Hermes-side iteration without clobbering edits, mutable may be correct.

### Prefer Normal Files In Hermes Skill State

Hermes must see normal files under `${stateDir}/.hermes/skills`, not store symlinks.

Also remember that a malformed local skill directory without `SKILL.md` can shadow the packaged skill and break loading.

## Debugging Heuristics

If behavior is wrong, ask these in order:

1. Is the behavior defined by upstream Hermes settings in `default.nix`?
2. Is it actually coming from patched Python runtime code in `patches/`?
3. Is mutable state under `${stateDir}/.hermes` preserving or shadowing something?
4. Is a platform-specific toolset narrowing the behavior on this surface?
5. Is activation rewriting the thing you just changed?

That sequence is usually faster than reading every file in the directory.

## What To Preserve

- `default.nix` stays the integration entrypoint.
- Verification targets `.#beast`, because this module is imported by `hosts/beast.nix`.
- Hermes identity comes from `${stateDir}/.hermes/SOUL.md`; `documents.AGENTS.md` is guidance, not primary identity.
- Writable shared roots stay limited to the configured NixOS repo, Obsidian vault, and projects root unless there is a deliberate trust change.
- Cron stays narrower than the main interactive surfaces unless there is a concrete reason to widen it.

## Verification

From `/etc/nixos`, use:

```text
nixos-rebuild dry-run --flake .#beast
nix flake check --print-build-logs
```

Use the dry-run for normal host validation. Use `nix flake check --print-build-logs` when the change is broad enough to justify the slower repo-wide check.

## What Good Looks Like

- New requests route quickly to one owning file.
- Runtime patching is explicit when it exists.
- Mutable state exists where Hermes needs it but does not silently override declarative intent.
- Trust boundaries stay narrow by default.
- Future edits require less reverse-engineering, not more.
