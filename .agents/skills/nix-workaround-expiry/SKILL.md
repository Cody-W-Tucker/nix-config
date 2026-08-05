---
name: nix-workaround-expiry
description: Policy for temporary NixOS/nixpkgs workarounds and insecure-package exceptions
---

# Nix Workaround Expiry

Every temporary workaround in this repo must be scannable and removable.

## Required for every broken-item workaround

1. **Rationale** — one-line comment explaining what is broken and why the workaround exists.
2. **Upstream link** — issue or PR URL tracking the fix.
3. **Concrete review/removal deadline** — `REVIEW-BY: YYYY-MM-DD` comment on the workaround line. Not "when upstream fixes it."
4. **Self-expiry Nix check** — a predicate + `warnings` entry that fires when the workaround is obsolete, *where a reliable predicate is available*.

When no reliable predicate exists (e.g., the upstream change is not observable from the consumer's config), the **deadline comment alone is required**. Revisit on that date.

## Distinguishing permanent config from workarounds

Permanent config does not need expiry: standard service options, feature-based package selection, module imports, stateVersion, networking.

Workarounds that need expiry: `permittedInsecurePackages` entries, version pins, temporary `mkForce` overrides, patches awaiting upstream, fallback packages.

## Predicate scope

A predicate must observe what the actual consumer selected, not a generic `pkgs.<pkg>.version` check. A generic fallback like `pkgs.docker` is *not* consumer-scoped — it does not prove the consumer uses that derivation. Prefer signals that come from the consumer's own module output (systemd unit text, `nativeBuildInputs`, propagated inputs, service backend option).

## Nix examples

### Version threshold / conditional fallback

```nix
let
  upstreamSafe = lib.versionAtLeast pkgs.foo.version "2.0.0";
in
{
  services.bar.package = if upstreamSafe then pkgs.foo else pkgs.foo-1_x;

  warnings = lib.optional
    (config.services.bar.enable && upstreamSafe)
    "foo is now ${pkgs.foo.version}; remove the fallback to foo-1_x.";
}
```

### Service-generated config / dependency predicate

```nix
let
  karakeepStillUsesPnpm9159 =
    config.services.karakeep.enable
    && builtins.any (dep: (dep.name or "") == "pnpm-9.15.9")
      (config.services.karakeep.package.nativeBuildInputs or []);
in
{
  warnings = lib.optional
    (config.services.karakeep.enable && !karakeepStillUsesPnpm9159)
    "Karakeep no longer uses pnpm-9.15.9; remove the exception from permittedInsecurePackages.";
}
```

Warnings fire when the consumer is enabled but the predicate (insecure dep still selected) is false — i.e., when the exception is obsolete. Disabled services do not trigger the "obsolete" warning because we cannot observe their deps.

## Placement

System-wide exceptions (insecure packages, shared workarounds): `hosts/fixes.nix`.
Service-specific workarounds: in the service module, prefixed with `# WORKAROUND` and the same three metadata lines.

## Review checklist before committing a workaround

- [ ] Rationale comment present
- [ ] Upstream issue/PR link present
- [ ] `REVIEW-BY: YYYY-MM-DD` date present
- [ ] Self-expiry predicate added if a reliable consumer-scoped signal exists; otherwise deadline comment only
- [ ] Warning fires when the exception becomes obsolete, not while it is still needed
- [ ] Predicate does not rely on a generic package fallback
