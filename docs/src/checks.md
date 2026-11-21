# Checks and standards

The repo enforces its standards with flake checks. `update` runs the first two steps itself; GitHub runs the rest on every pull request.

## What is checked

| Check | Fails on | Runs in |
| --- | --- | --- |
| `formatting` | Nix not formatted with nixfmt. `nix fmt` corrects it. | `update` (as `nix fmt`), PRs |
| `imports` | A `default.nix` outside a `_` path under `modules/`, or a `_` subtree whose `default.nix` misses a sibling or imports a missing file | `update` (as `check-imports`), PRs |
| `statix`, `deadnix` | Lint warnings, unused bindings | PRs |
| `docs` | This book does not build, or links a repo file that does not exist | PRs, and the docs deploy |

On a pull request, the full `nix flake check` runs only when the `NIX_SECRETS_READ` token is available; without it, only formatting and lint run.

## Running them

| Command | Use |
| --- | --- |
| `nix flake check` | Evaluate both hosts and run every check |
| `nix build .#checks.x86_64-linux.<name>` | Run one check |
| `nixos-rebuild build --flake .#<host>` | Build a host without activating it |

New files must be `git add`ed before Nix sees them.

## Changing it

| To change | Edit |
| --- | --- |
| The checks | [`modules/flake/checks.nix`](../../modules/flake/checks.nix) |
| Lint rules | [`statix.toml`](../../statix.toml) |
| PR checks | [`.github/workflows/`](../../.github/workflows) |
