---
name: nix-workaround-expiry
description: Policy for temporary NixOS/nixpkgs workarounds and insecure-package exceptions
---

# Nix Workaround Expiry

Every temporary workaround in this repo declares a `codyos.workarounds.<name>` entry next to the code it changes. The entry is the reminder: [`modules/nix/workarounds.nix`](../../../modules/nix/workarounds.nix) turns it into a build warning. The repo has no comments, so nothing else records the workaround in the source.

## Required for every workaround

```nix
codyos.workarounds.<name> = {
  reason = "What is broken upstream, and which binding works around it.";
  upstream = "https://github.com/<owner>/<repo>/issues/<n>";
  reviewBy = "YYYY-MM-DD";
  obsolete = <consumer-scoped predicate>;
};
```

1. **`reason`**: what is broken and the binding or option the workaround sits on.
2. **`upstream`**: the issue, pull request or commit that tracks the fix.
3. **`reviewBy`**: a concrete date. Not "when upstream fixes it." Every build warns once `inputs.self.lastModifiedDate` (the last commit's date) reaches it.
4. **`obsolete`**: a predicate that is true once the workaround is no longer needed. Every build then warns to remove it, before the review date. Leave it at the default `false` only when no reliable consumer-scoped signal exists, and say why in `reason`.

The option exists in both NixOS and Home Manager modules. Names are unique per host and user, so give two copies of one workaround two names.

Optionally also retain the investigation in Hindsight (bank `codyos`, tags `source-note`, `kind:workaround`, `file:<path>`).

## Distinguishing permanent config from workarounds

Permanent config does not need an entry: standard service options, feature-based package selection, module imports, stateVersion, networking.

Workarounds that need an entry: `permittedInsecurePackages` entries, version pins, temporary `mkForce` overrides, patches awaiting upstream, fallback packages.

## Predicate scope

A predicate must observe what the actual consumer selected, not a generic `pkgs.<pkg>.version` check. A generic fallback like `pkgs.docker` is *not* consumer-scoped: it does not prove the consumer uses that derivation. Prefer signals from the consumer's own inputs or module output: the upstream derivation you override, systemd unit text, `nativeBuildInputs`, the service package option, or the flake input the host actually uses.

Do not read a fetched source at evaluation time (`builtins.readFile "${src}/..."`); that is import-from-derivation. When a patch uses `--replace-fail`, the build already fails once the patched text disappears; say so in `reason`.

## Nix examples

### Version threshold

```nix
codyos.workarounds.mealie-unstable = {
  reason = "Stable ships Mealie ${pkgs.mealie.version}, but the database was migrated by 3.22.0, so services.mealie.package tracks unstable.";
  upstream = "https://github.com/NixOS/nixpkgs/commits/master/pkgs/by-name/me/mealie";
  reviewBy = "2027-02-27";
  obsolete = lib.versionAtLeast pkgs.mealie.version "3.22.0";
};
```

### Upstream derivation predicate

```nix
codyos.workarounds.ai-usagebar-sqlite = {
  reason = "ai-usagebar's package omits SQLite, so aiUsagebar adds it to buildInputs.";
  upstream = "https://github.com/akitaonrails/ai-usagebar/blob/main/nix/package.nix";
  reviewBy = "2027-02-27";
  obsolete = lib.any (dep: lib.getName dep == "sqlite") (upstreamAiUsagebar.buildInputs or [ ]);
};
```

### Insecure-package exception

```nix
codyos.workarounds.karakeep-pnpm = {
  reason = "Karakeep builds with pnpm-9.15.9, so it is in permittedInsecurePackages.";
  upstream = "https://github.com/karakeep-app/karakeep/issues/<n>";
  reviewBy = "2027-01-15";
  obsolete =
    config.services.karakeep.enable
    && !builtins.any (dep: (dep.name or "") == "pnpm-9.15.9") (
      config.services.karakeep.package.nativeBuildInputs or [ ]
    );
};
```

A disabled consumer must not make `obsolete` true, because its dependencies cannot be observed.

## Review checklist before committing a workaround

- [ ] `codyos.workarounds.<name>` entry in the same module as the workaround
- [ ] `reason` names the binding or option it sits on
- [ ] `upstream` link present
- [ ] `reviewBy` date present
- [ ] `obsolete` predicate added if a reliable consumer-scoped signal exists
- [ ] `obsolete` is `false` today: evaluate it on every host that uses the workaround
- [ ] Predicate does not rely on a generic package fallback or read a fetched source
