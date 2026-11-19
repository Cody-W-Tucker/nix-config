# CodyOS

You are assisting a user working on a NixOS system config using flakes. Full documentation is available at `docs/`.

## Capability Floor

When planning new features. The evaluated config is the map of what each host can do.

```bash
# Declared capabilities for a host (nas or beast).
nix eval --json .#nixosConfigurations.nas.config --apply 'c:
  let hm = c.home-manager.users.codyt; in
  builtins.mapAttrs (_: builtins.attrNames) {
    services = c.systemd.services;
    timers = c.systemd.timers;
    userServices = hm.systemd.user.services;
    userTimers = hm.systemd.user.timers;
    containers = c.virtualisation.oci-containers.containers;
  }'
```

- Declared is not running. Confirm on the host itself with `systemctl` (`--user` for user units) before treating a capability as available.
- When work needs a capability that is not on the floor, declare it in Nix first, then build on it.

## Evidence Discipline

- Before declaring an audit or evidence report complete, map every acceptance criterion to direct source or evaluated evidence and explicitly mark anything unverified. A behavioral criterion requires a focused runtime test; source inspection alone is insufficient.
- Before citing a file, open and read it in the current session; grep/search output does not count. For exhaustive inventories, enumerate every relevant exact path instead of using wildcard summaries, and inspect every search hit and referenced file.
- Verify claims about upstream options, NixOS behavior, and override/build semantics in authoritative documentation, source, or tests; search snippets are not evidence.
- Validation status must be the validated command's status. Do not pipe through `head` or `tail` unless `pipefail` or `PIPESTATUS` preserves it. Report success only when both status and output demonstrate it; inspect failures, correct the invocation, and rerun.

## Change Validation

Identify the affected hosts and expected behavior, then choose the smallest checks that can provide meaningful evidence, in this order:

1. For existing option values and package-list changes, evaluate the relevant merged values on each affected host; run a focused check when useful.
2. For packages, scripts, generated configuration, and plugins, build and test the changed artifact or behavior directly when practical.
3. For significant module wiring, new services, or host-spanning changes, build the affected host closure before declaring validation complete unless a narrower artifact build directly covers the likely failures; `nix flake check` or a dry-run is not a substitute.

Use `nix flake check` when repository-wide validation is appropriate, such as broad refactors or flake-input changes. It evaluates both hosts and runs the declared checks; it does not build every package or host closure, activate a system, or prove runtime behavior. Individual checks can be run with `nix build .#checks.x86_64-linux.<name>`.

Run focused behavioral checks where possible, and report what passed and what remains unverified. Evaluation can run from either host, but claims about actual hardware, services, secrets, or network behavior require evidence from the affected host. Do not activate, switch, or run `nixos-rebuild test` without the user's authorization. If a check fails, inspect the error and address it; do not claim validation that was not performed.

```bash
# Repository-wide evaluation and declared checks. Stage new files first.
nix flake check

# Example: build an affected package or host without activation.
nix build --no-link .#update
nix build --no-link .#nixosConfigurations.nas.config.system.build.toplevel
```

Once the changes have settled, the user will run the `update` script to build and activate the system.

## High-value repo rules

### Editing

- Keep narrowly scoped edits minimal: preserve unrelated lines and comments, and avoid repository-wide formatting. Before summarizing Git state or claiming no unrelated files were touched, inspect status and the complete staged and unstaged diff for every modified or unmerged path; enumerate relevant changed files by exact path.

### Naming & Files

- Use lowercase kebab-case for all file names
- Match upstream package names when practical; use CLI-safe kebab-case for internal scripts
- Use quoted attribute names for secret keys with dashes: `sops.secrets."paperless-password"`

### Module Structure

- `flake.nix` is inputs plus one `evalModules` over `inputs.den.flakeModule` and `import-tree ./modules`; its `.config.flake` is every flake output. Every non-underscore `.nix` under `modules/` is a flake-level Den module: hosts in `modules/hosts/<host>.nix`, `modules/desktop/desktop.nix`, other aspects in `modules/{hardware,users,editor,harness,web,feeds,backups,observability,services,server}/`, and non-host flake outputs (`overlays`, `packages`, `checks`, `formatter`) in `modules/flake/`. Plain NixOS/Home Manager modules, scripts and data live under `_` paths and are imported by their aspect. See `modules/README.md` and `docs/Den-Native-Layout.md`.
- No `default.nix` outside `_` paths (`check-imports` enforces it).
- Naming: new code follows `docs/Den-Native-Layout.md`.
- Keep `default.nix` short.
  - Use supporting files with self-explaining names if needed.
  - Examples: `module.nix`, `package.nix` and `service.nix`.
- Keep secrets declarations close to their consuming service

### Flakes & Git

- New files must be git-tracked or flakes won't see them
- When code changes invalidate local docs or package notes, update the affected documentation in the same change.
- Never commit raw secrets (use SOPS-NIX.)
- The user will need to add secrets via the sops edit command.

## Tracing Configuration: Evaluate, Don't Scan

For any claim about effective Nix configuration—including presence, absence, conflicts, defaults, contributors, or host capability—evaluate the merged configuration before searching or reading module trees. Never infer effective state from imports or source assignments alone. Use Grep only for plain text (comments, strings inside scripts, docs). Replace `<host>` with `nas` or `beast`; each command takes about a second once the flake is cached.

```bash
# Which files contribute definitions for an option
nix eval --json .#nixosConfigurations.<host>.options.networking.firewall.interfaces.definitionsWithLocations \
  --apply 'map (d: d.file)'

# The final merged value
nix eval --json .#nixosConfigurations.<host>.config.services.nginx.enable

# Where an option is declared (upstream module or a codyos.* option here)
nix eval --json .#nixosConfigurations.<host>.options.codyos.site.domain.declarationPositions

# Home Manager values for the primary user
nix eval --json .#nixosConfigurations.<host>.config.home-manager.users.codyt.programs.opencode.settings.small_model
```

- An option that differs between hosts needs one query per host; do not infer one from the other.
- Definition locations show contributors, not every consumer. Evaluate affected values on both hosts and inspect the contributing sources before judging impact.
- For attribute-set options (`systemd.services`, `services.nginx.virtualHosts`), query the option itself to list every contributing file, then narrow with the specific attribute under `config`.
- Values that are derivations or functions do not serialize; select a leaf (`.drvPath`, `.name`) or drop `--json`.
- New files must be `git add`-ed before these commands can see them.
- Hosts are assembled by Den, but `nixosConfigurations.<host>` evaluates to an ordinary NixOS system, so every command above is unchanged. Definition locations for options set from an aspect point at the `modules/<area>/*.nix` file that defines the aspect (or at Den-generated modules).
