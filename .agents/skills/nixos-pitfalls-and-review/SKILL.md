---
name: nixos-pitfalls-and-review
description: Use before NixOS/Nix module changes or audits that assert merged or upstream option semantics, trace complete NixOS/Home Manager argument wiring, report locked dependency versions with exact revisions and timestamps, validate builds, diagnose network reachability, or schedule services that must not overlap.
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

### 4. Mixing packages and modules

If a file builds a derivation, it is a package in `packages/`, not a module in `modules/`.

### 5. Treat timer offsets as load shaping, not exclusion

When recurring services must not overlap, encode explicit systemd coordination or mutual exclusion, such as unit relationships, conditions, or a shared lock. A different `OnCalendar` time alone is not a guarantee because a long run can cross into another job's window.

## Evidence for audits and recommendations

- Map every acceptance criterion to direct source or evaluated evidence, and mark anything unverified. A behavioral claim needs a focused runtime test; reading source is not enough.
- Open and read a file in this session before citing it; a search hit is not a reading. For an exhaustive inventory, list every exact path rather than a wildcard summary.
- Verify upstream option, NixOS and override semantics in authoritative docs, source or tests, not search snippets.
- Before recommending a Nix option, verify it against the local module or package source and give its complete enclosing attribute path.
- When merge semantics determine a value, evaluate the resulting configuration when feasible; clearly distinguish evaluated output from an expected merge.
- When auditing NixOS policy, evaluate the resulting configuration when feasible and distinguish evaluated values from source-level expectations.
- When verifying module arguments, inspect the complete NixOS and Home Manager wiring and demonstrate that required arguments are passed through `specialArgs` or `extraSpecialArgs`.
- When auditing a packaged integration or dependency version, inspect flake inputs, lock data, and the package-resolution path; report the exact locked revision and timestamp when available.

## Review checklist

When reviewing a NixOS change, ask:

- Does it follow `modules/AGENTS.md` and the nearest `AGENTS.md`?
- Is the host file still only machine facts?
- Is the change using module-system helpers where merge semantics matter?
- Is every new file tracked, so the flake sees it?
- Was it checked as root `AGENTS.md` "Change Validation" describes?

## Network reachability diagnosis

Verify the failing path from the affected client. If that is not possible, explicitly mark client-side reachability as unverified.

## Anti-patterns to avoid

- deep folder trees with little meaning
- one massive host file containing everything
- one massive shared module containing everything
- custom abstractions that nobody can explain quickly

## Rule of thumb

The best standards reduce guesswork. If a contributor can predict where a change belongs before searching, the structure is working.
