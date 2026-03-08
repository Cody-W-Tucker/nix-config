---
name: nixos-pitfalls-and-review
description: Common mistakes in NixOS code and standards for reviewing and refactoring NixOS repositories
---

# NixOS Pitfalls And Review

## The biggest hidden context: NixOS modules are not sequential programs

NixOS modules are evaluated together and merged through the module system. This has important consequences:

- import order is not normal execution order
- values are merged, not assigned imperatively
- thinking procedurally causes many common mistakes

## High-impact pitfalls

### 1. Confusing the Nix language with the module system

Prefer module-system primitives inside modules:

- use `imports = [ ... ]` instead of ad hoc `import` wiring for modules
- use `lib.mkIf` instead of raw top-level `if` for conditional config
- use `lib.mkMerge`, `lib.mkBefore`, `lib.mkAfter`, and `lib.mkForce` when merge semantics matter

### 2. Reading `config` too early

Do not read merged config values in module top-level bindings unless you know the evaluation rules.

Risky pattern:

```nix
{ config, ... }:
let
  enabled = config.services.nginx.enable;
in
{
  # may cause recursion or surprising evaluation problems
}
```

Safer pattern:

```nix
{ config, lib, ... }:
{
  config = lib.mkIf config.services.nginx.enable {
    # ...
  };
}
```

### 3. Over-engineering custom options

Do not create a custom option layer for every single setting.

Create custom options when:

- multiple hosts share the feature
- you need an `enable` switch
- you want a stable internal interface
- you want defaults plus host overrides

Do not create them when a plain module import and a few direct assignments are enough.

### 4. Thick host files

Hosts should not become giant copies of service configuration. Put reusable service logic in modules and keep hosts focused on machine identity.

### 5. Misplacing `stateVersion`

- `system.stateVersion` belongs in the host, not in a shared global file.
- `home.stateVersion` belongs in the user or Home Manager config.
- Different hosts may legitimately use different versions.

### 6. Forgetting that flakes only see tracked files

With flakes, untracked files are often invisible to evaluation.

- new files should be added to git before expecting builds to see them
- this is a very common source of confusing "file not found" errors

### 7. Mixing packages and modules

- package definitions belong in `pkgs/`
- reusable system behavior belongs in `modules/`

If a file builds a derivation, it is usually a package file, not a NixOS module.

### 8. Hiding secrets assumptions

- declare secrets close to the service that consumes them
- never commit raw secrets
- remember that secret tooling adds operational requirements for builds and deployment

## Recommended architecture patterns

### Import-all, enable-selectively

For larger repos, import a stable set of modules and enable them with options instead of hand-curating imports per host.

Benefits:

- hosts stay smaller
- shared defaults live in one place
- new features scale better across many machines

### Single responsibility modules

Each module should answer one question clearly:

- how is this service configured?
- how is this hardware handled?
- how is this user environment defined?

## Review checklist

When reviewing a NixOS change, ask:

- Is the file in the right category?
- Is the file name obvious and consistent?
- Is the host file still mostly machine-specific?
- Is `stateVersion` local to the host or user?
- Are secrets declared near use?
- Are package definitions separated from NixOS modules?
- Is the module boundary clear and single-purpose?
- Is the change using module-system helpers where merge semantics matter?
- Will flakes see every new file because it is tracked?

## Validation checklist

Run at least:

- `nix flake check`
- `nixos-rebuild build --flake .#<host>`

If using Home Manager through NixOS, also validate the relevant host build rather than only checking formatting.

## Anti-patterns to avoid

- deep folder trees with little meaning
- one massive host file containing everything
- one massive shared module containing everything
- custom abstractions that nobody can explain quickly
- putting real config into import-only aggregator files

## Rule of thumb

The best standards reduce guesswork. If a contributor can predict where a change belongs before searching, the structure is working.
