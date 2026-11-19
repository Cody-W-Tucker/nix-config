# CodyOS

**CodyOS uses Den to compose NixOS and Home Manager by feature.** Start with the nearest existing `den.aspects.*` definition in `modules/`. Use `nixosConfigurations.<host>` for ordinary NixOS option evaluation and builds. See the [Den layout](docs/Den-Native-Layout.md) and [module map](modules/README.md).

## Capability Floor

When planning a feature or auditing what a host declares, use the [capability inventory](docs/Den-Native-Layout.md#declared-host-capabilities). For a known feature, query its specific setting instead.

- Declared is not running. Confirm on the host itself with `systemctl` (`--user` for user units) before treating a capability as available.
- When work needs a capability that is not on the floor, declare it in Nix first, then build on it.

## Evidence Discipline

- Before declaring an audit or evidence report complete, map every acceptance criterion to direct source or evaluated evidence and explicitly mark anything unverified. A behavioral criterion requires a focused runtime test; source inspection alone is insufficient.
- Before citing a file, open and read it in the current session; grep/search output does not count. For exhaustive inventories, enumerate every relevant exact path instead of using wildcard summaries, and inspect every search hit and referenced file.
- Verify claims about upstream options, NixOS behavior, and override/build semantics in authoritative documentation, source, or tests; search snippets are not evidence.
- Validation status must be the validated command's status. Do not pipe through `head` or `tail` unless `pipefail` or `PIPESTATUS` preserves it. Report success only when both status and output demonstrate it; inspect failures, correct the invocation, and rerun.

## Change Validation

Identify the aspect, affected hosts, and expected behavior. Choose the smallest check that can catch the likely failure:

- **Feature logic:** Evaluate an aspect in isolation with explicit fixture inputs when that answers the question or gives you a useful regression test. This does not prove that a real host selects it or gets the same result.
- **Composition and settings:** Trace Den when the inclusion or routing is unclear. For a setting or package-list change, evaluate the relevant merged value on each affected host rather than building its closure by default.
- **Artifacts and behavior:** Build and test the changed package, script, generated configuration, or plugin directly when practical. For significant wiring, new services, or changes spanning hosts, build the affected host closure if narrower checks do not cover the likely failures. A dry run or `nix flake check` is not a substitute for that build.

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

- `modules/hosts/<host>.nix` owns machine facts and selects features. Feature aspects own the implementation, including the NixOS and Home Manager pieces and nested sides such as `nfs.server` and `nfs.client`.
- Inclusion is the feature switch. A feature intended for every host registers itself through `den.default.includes`; otherwise select it on the hosts that need it.
- `import-tree` loads flake-level modules under `modules/` and skips paths containing a `_`-prefixed segment. Keep plain modules, scripts, and data in those excluded paths and import them explicitly. Under `modules/`, `default.nix` is allowed only on excluded paths (`check-imports` enforces this).
- Keep shared facts in `codyos.site` and secret declarations next to their consuming service. Non-host flake outputs live in `modules/flake/`.

### Flakes & Git

- New files must be git-tracked or flakes won't see them
- When code changes invalidate local docs or package notes, update the affected documentation in the same change.
- Never commit raw secrets (use SOPS-NIX.)
- The user will need to add secrets via the sops edit command.

## Finding and Verifying Configuration

- **Effective settings:** Use `nix eval` on the relevant merged option for each affected host. Search source to find definitions and consumers, not to decide what the host gets.
- **Den composition:** Use the [working trace recipe](docs/Den-Native-Layout.md#focused-evaluation-and-tracing) (`den.lib.capture.captureWithPathsWith`) when an aspect's route to a host or user is unclear. If the route is easier to explain visually, use the [Den resolution graph](docs/Den-Native-Layout.md#den-resolution-graphs). Neither the trace nor the graph proves merged values or runtime behavior.
