# CodyOS

NixOS and Home Manager for two hosts, `beast` (desktop) and `nas` (server), composed by feature with [Den](modules/AGENTS.md). Each feature is a `den.aspects.<feature>` file under `modules/`; start from the nearest existing one.

## Making Changes

Pick the route before writing any repository file. Write the commit messages yourself.

- **Pull request (default):** `git fetch origin`, then `git worktree add -b <branch> ~/worktrees/codyos/<branch> origin/main`. Never work in `/etc/nixos` or under `~/Projects` (synced between hosts). Commit there and run `/no-mistakes` with the user's request as the intent. Bring every `ask-user` finding to the user. At `checks-passed`, give the user the PR link. When they say merge, run `gh pr merge --squash --delete-branch` and remove the worktree.
- **Direct to main:** only when the user says so. In `/etc/nixos`, run the `lint` command from `.no-mistakes.yaml` before committing. Do not push.

Either way the user runs `update` afterwards. Do not run it, and never activate (`nixos-rebuild switch`/`test`/`boot`) without the user's authorization.

## Change Validation

Check only what the change can affect, with the smallest check that catches the likely failure. A prose-only change needs only a diff review.

- **One setting or package list:** `nix eval --json .#nixosConfigurations.<host>.config.<option>` on each affected host. Search finds where a value is defined; evaluation decides what the host gets.
- **Wiring, a new service, a flake input, or several hosts:** use the `nix-diff-audit` skill to see exactly what changed in each host's closure.
- **A package, script or generated file:** build it, e.g. `nix build --no-link .#<name>`, and run it.
- **Unclear Den routing:** use the `den-trace` skill.

The pipeline's `host-build` gate builds both hosts, so do not build host closures by default. Use `nix build .#checks.x86_64-linux.<name>` for one check instead of `nix flake check`. Report a check as passed only from its exit status and output; do not hide the status behind `| head` or `| tail`, and a pending check has not passed. Claims about hardware, services, secrets or networking need evidence from the affected host.

## Rules

- **Docs:** the no-mistakes document step writes `docs/src/`. Never edit it by hand, even when the request is about docs. To learn what normal looks like for a feature, read its page.
- **No comments in Nix.** Names and structure carry the meaning (the `no-comments` check enforces it). Keep a constraint, an opaque value's meaning, or a benchmark in Hindsight (bank `codyos`, tags `source-note`, `file:<path>`), and recall that tag before changing a file. Temporary workarounds use the `nix-workaround-expiry` skill.
- **Nice-to-haves take the upstream default.** Configure a small convenience as its docs say, themed only through settings the tool already has (Stylix colours, not literals). Do not write a wrapper, patch or package to close a cosmetic gap; report the gap.
- **Files:** lowercase kebab-case names; match upstream package names. New files must be `git add`ed or the flake cannot see them. Put durable editing rules in the nearest `AGENTS.md`, not a README.
- **Secrets:** SOPS only, declared next to the consuming service; quote dashed keys (`sops.secrets."paperless-password"`). The user adds secrets with `sops edit` and pushes `nixos-secrets`; when they say it is pushed, run `nix flake update nixos-secrets` and commit the lock.
- **Before a summary or commit,** read `git status` and the full diff of every changed path, not `--stat`, and name the changed files.
