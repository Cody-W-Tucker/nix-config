---
name: nixos-organization
description: Designing and maintaining the top-level layout of a NixOS flake-based configuration repository
---

# NixOS Organization

## Goal

Keep the repository easy to navigate, easy to grow, and easy to debug. Favor a small number of predictable top-level directories over deep nesting.

## Recommended top-level layout

```text
.
|- flake.nix
|- flake.lock
|- hosts/
|- modules/
|- home/            # or users/
|- pkgs/            # optional custom packages
|- lib/             # optional helper functions
|- secrets/
`- docs/            # optional project docs
```

## What belongs where

### `flake.nix`

- Define inputs.
- Expose `nixosConfigurations` and other flake outputs.
- Keep it focused on wiring, not detailed service logic.

### `hosts/`

- One host per file or per directory.
- Keep host files thin.
- Put host-specific imports, disks, boot, hardware, hostname, and machine overrides here.
- Do not turn host files into giant service catalogs.

### `modules/`

- Reusable NixOS modules by feature or domain.
- Good categories include `system/`, `services/`, `networking/`, `desktop/`, `hardware/`, and `security/`.
- Each module should have a single clear reason to change.

### `home/` or `users/`

- Home Manager modules and user-level configuration.
- Prefer `home/` for a single-user repo.
- Prefer `users/` when multiple users share the repo.

### `pkgs/`

- Custom packages, wrappers, and scripts built as packages.
- Do not mix package definitions into general-purpose system modules.

### `lib/`

- Shared helper functions.
- Keep this small. If logic is only used once, keep it local instead of abstracting too early.

### `secrets/`

- SOPS or agenix declarations and encrypted material only.
- Never store raw secrets.

## Common directory patterns

### Flat host pattern

```text
hosts/
|- beast.nix
|- server.nix
|- aiserver.nix
```

Best when hosts are simple and the repo is still compact.

### Per-host directory pattern

```text
hosts/
`- beast/
   |- default.nix
   |- hardware-configuration.nix
   |- disks.nix
```

Best when a host has several machine-specific files.

### Module category pattern

```text
modules/
|- system/
|- services/
|- networking/
|- desktop/
|- hardware/
|- security/
```

This is the most common long-term structure for growing repos.

## Practical standards

- Keep top-level directories semantic and stable.
- Keep `default.nix` files as import aggregators whenever possible.
- Keep machine-specific state in `hosts/`, reusable behavior in `modules/`.
- Keep Home Manager separate from NixOS modules even if both live in one flake.
- Keep custom packages in `pkgs/` instead of `modules/`.

## Notes for the current repo shape

- `packages/scripts/` is used for custom script packages that define installable packages or wrappers.

## Rule of thumb

If a file answers "what does this machine need?" it probably belongs in `hosts/`.

If a file answers "how should this feature work anywhere it is enabled?" it probably belongs in `modules/`.
