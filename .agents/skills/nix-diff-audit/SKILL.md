---
name: nix-diff-audit
description: Verify NixOS configuration changes before activation using nvd and nix-diff to prevent unintended package drift, service changes, or mass rebuilds.
---

# NixOS Closure & Derivation Verification

## When to Use

Use when a change could alter a host's closure in ways you need to see: a `flake.lock` update, new or rewired services, shared modules that touch several hosts, or a rebuild that turned out larger than expected. It shows exactly what changed, which a search or a single `nix eval` cannot. For a single setting, evaluating the merged option is still the cheaper check.

Never activate. Report the audit; the user deploys with `update`.

`nvd` and `nix-diff` are on the agent shell's PATH. If they are missing (the runtime has not been activated yet), use `nix shell nixpkgs#nvd nixpkgs#nix-diff --command ...`.

## Choose the Baseline

- **`origin/main`** shows everything on a PR branch, and works for either host from either machine. Prefer it in a worktree.
- **`HEAD`** shows only the uncommitted change.
- **`/run/current-system`** also includes commits that were never activated. It is only meaningful for the host you are on.

New files must be staged with `git add` first, or the worktree build will not see them.

```bash
host=nas   # or beast
attr="nixosConfigurations.$host.config.system.build.toplevel"
base="git+file://$PWD?rev=$(git rev-parse origin/main)#$attr"   # or HEAD
```

## Step 1: Derivation Diff (`nix-diff`), no build needed

`nix-diff` compares `.drv` files, so evaluation alone is enough (about 35 s per host):

```bash
old=$(nix eval --raw "$base.drvPath")
new=$(nix eval --raw ".#$attr.drvPath")
out=$(mktemp)
nix-diff --color never --skip-already-compared --squash-text-diff --context 2 "$old" "$new" > "$out"
echo "status=$? lines=$(wc -l < "$out")"
```

Then read `$out`. Do not pipe `nix-diff` into `head`; that hides its exit status.

Read the indented tree from the top down. Each `The input derivation named X differs` line is one step in the path to the real change, for example `etc` → `system-units` → `unit-home-manager-codyt.service` → … The leaf entries (`set of input derivation names`, `environments do not match`) are the actual change. Confirm that each leaf matches the request. A leaf the request did not mention, such as another service or a compiler, is drift.

Secrets: SOPS values should show up as `/run/secrets/...` paths. A literal token, password or key in an environment diff means a secret reached `/nix/store`.

## Step 2: Package Drift (`nvd`), needs built closures

`nvd` compares built outputs. Build into a temporary directory, never into `./result` in the repo:

```bash
d=$(mktemp -d)
nix build -o "$d/new" ".#$attr"
nix build -o "$d/old" "$base"   # or skip and use /run/current-system on this host
nvd diff "$d/old" "$d/new"
echo "nvd status=$?"
rm -rf "$d"
```

- `[A.]` / `[R.]` are added and removed packages, `[U.]` upgrades, `[D.]` downgrades. Each should match the request.
- `No version or selection state changes.` is normal for config-only changes; rely on Step 1 for those.
- Check the `Closure size:` line. An unexpected jump in paths or disk usage, or many changed paths for a small edit, means a mass rebuild; trace it with Step 1.

## Report

State the baseline you used, each tool's exit status, every added, removed or changed package or leaf, and anything unexpected. Say which host(s) you audited.
