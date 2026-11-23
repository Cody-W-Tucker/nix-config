# CodyOS

**CodyOS uses Den to compose NixOS and Home Manager by feature.** Start with the nearest existing `den.aspects.*` definition in `modules/`. Use `nixosConfigurations.<host>` for ordinary NixOS option evaluation and builds. See the [Den conventions](modules/AGENTS.md) and the [Den layout](docs/src/den-native-layout.md) overview.

## Capability Floor

When planning a feature or auditing what a host declares, use the [capability inventory](modules/AGENTS.md#declared-host-capabilities). For a known feature, query its specific setting instead.

- Declared is not running. Confirm on the host itself with `systemctl` (`--user` for user units) before treating a capability as available.
- When work needs a capability that is not on the floor, declare it in Nix first, then build on it.

## Docs Are the Baseline

`docs/src/` maps the system as the user meets it: what they press, open or run, and what they then see. That is the agreed baseline. The code, Hindsight and deja hold everything beneath it: implementation, decisions and their reasons, benchmarks, history.

- When a report is vague ("this is slow", "this works differently"), read the feature's page for what normal is first, then recall its history (Hindsight, deja, and `git log` on the aspect's files), then check the host. The page, the aspect and that history are three views of one feature; the file paths and aspect name join them.
- When a change alters what the user experiences, update that feature's page in the same change, following [Writing these docs](docs/src/writing-docs.md#what-a-page-records). Record only what is specific to this system and visible to the user; omit general knowledge, config recaps and the reasons for choices. Never invent a behavior or a number.
- Keep operator guidance in `docs/` and durable editing rules in the nearest `AGENTS.md`. Keep local READMEs for temporary workarounds with a removal condition, not permanent feature maps. Keep source comments for non-obvious constraints, not inline usage guides.

## Evidence Discipline

- Before declaring an audit or evidence report complete, map every acceptance criterion to direct source or evaluated evidence and explicitly mark anything unverified. A behavioral criterion requires a focused runtime test; source inspection alone is insufficient.
- Before citing a file, open and read it in the current session; grep/search output does not count. For exhaustive inventories, enumerate every relevant exact path instead of using wildcard summaries, and inspect every search hit and referenced file.
- Verify claims about upstream options, NixOS behavior, and override/build semantics in authoritative documentation, source, or tests; search snippets are not evidence.
- Validation status must be the validated command's status. Do not pipe through `head` or `tail` unless `pipefail` or `PIPESTATUS` preserves it. Report success only when both status and output demonstrate it; inspect failures, correct the invocation, and rerun.

## Change Validation

Verify only what the change can affect. Start with the smallest check that can catch the likely failure, and stop when it gives enough evidence. For a prose-only edit, reviewing the diff may be enough; don't run Nix checks just because the repo uses Nix. For Nix changes, choose the relevant check:

- **Feature logic:** Evaluate an aspect in isolation with explicit fixture inputs when that answers the question or gives you a useful regression test. This does not prove that a real host selects it or gets the same result.
- **Composition and settings:** Trace Den when the inclusion or routing is unclear. For a setting or package-list change, evaluate the relevant merged value on each affected host rather than building its closure by default.
- **Artifacts and behavior:** Build and test the changed package, script, generated configuration, or plugin directly when practical. For significant wiring, new services, or changes spanning hosts, build the affected host closure if narrower checks do not cover the likely failures. A dry run or `nix flake check` is not a substitute for that build.

`nix flake check` is not a default or required final step. Use it only when the change needs repository-wide validation, as a broad refactor or flake-input change might. If only one declared check is relevant, run `nix build .#checks.x86_64-linux.<name>` instead.

Run focused behavioral checks where possible, and report what passed and what remains unverified. Evaluation can run from either host, but claims about actual hardware, services, secrets, or network behavior require evidence from the affected host. Do not activate, switch, or run `nixos-rebuild test` without the user's authorization. If a check fails, inspect the error and address it; do not claim validation that was not performed.

```bash
# Example: build an affected package or host without activation.
nix build --no-link .#update
nix build --no-link .#nixosConfigurations.nas.config.system.build.toplevel
```

Once the changes have settled, the user will run the `update` script to build and activate the system.

## High-value repo rules

### Editing

- Keep narrowly scoped edits minimal: preserve unrelated lines and comments, and avoid repository-wide formatting. Before summarizing Git state or claiming no unrelated files were touched, inspect status and the complete staged and unstaged diff for every modified or unmerged path; enumerate relevant changed files by exact path.
- **For a nice-to-have, take the upstream default.** Configure a small convenience the way its own documentation does, and theme it only through a configuration surface the tool already supports — Home Manager generating that file is fine, and it should carry Stylix colours rather than literals. Do not write a wrapper, patch, package or post-processing step to close a cosmetic gap: report the gap and leave it. The user asks explicitly when a nice-to-have is worth more than that.

### Naming & Files

- Use lowercase kebab-case for all file names
- Match upstream package names when practical; use CLI-safe kebab-case for internal scripts
- Use quoted attribute names for secret keys with dashes: `sops.secrets."paperless-password"`

### Module Structure

- `modules/hosts/<host>.nix` owns machine facts and host-local settings. Feature files own selection and implementation, including the NixOS and Home Manager pieces and nested sides such as `nfs.server` and `nfs.client`.
- Inclusion is the feature switch. In the owning feature file, use `den.aspects.<host>.includes = [ den.aspects.<feature> ];` for a named host or `den.default.includes` for a shared feature. Use the schema for typed facts and global policies, not for fixed host selection.
- `import-tree` loads flake-level modules under `modules/` and skips paths containing a `_`-prefixed segment. Keep plain modules, scripts, and data in those excluded paths and import them explicitly. Under `modules/`, `default.nix` is allowed only on excluded paths (`check-imports` enforces this).
- Keep shared facts in `codyos.site` and secret declarations next to their consuming service. Non-host flake outputs live in `modules/flake/`.

### Flakes & Git

- New files must be git-tracked or flakes won't see them
- Never commit raw secrets (use SOPS-NIX.)
- The user will need to add secrets via the sops edit command.

## Finding and Verifying Configuration

- **Effective settings:** Use `nix eval` on the relevant merged option for each affected host. Search source to find definitions and consumers, not to decide what the host gets.
- **Den composition:** Use the [working trace recipe](modules/AGENTS.md#focused-evaluation-and-tracing) (`den.lib.capture.captureWithPathsWith`) when an aspect's route to a host or user is unclear. If the route is easier to explain visually, use the [Den resolution graph](modules/AGENTS.md#den-resolution-graphs). Neither the trace nor the graph proves merged values or runtime behavior.
