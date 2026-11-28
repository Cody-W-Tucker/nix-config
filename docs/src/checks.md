# Checks and standards

The repo enforces its standards with flake checks. The no-mistakes pipeline runs them before merge; GitHub builds the book on pull requests.

## What is checked

| Check | Fails on | Runs in |
| --- | --- | --- |
| `formatting` | Nix not formatted with nixfmt. `nix fmt` corrects it. | no-mistakes, PRs |
| `imports` | A `default.nix` outside a `_` path under `modules/`, or a `_` subtree whose `default.nix` misses a sibling or imports a missing file | no-mistakes |
| `statix`, `deadnix` | Lint warnings, unused bindings | no-mistakes, PRs |
| `no-comments` | Any Nix comment. `ast-grep scan --update-all .` then `nix fmt` deletes them. OpenCode, Claude Code and Neovim show the same error as you type. | no-mistakes |
| `docs` | This book does not build, or links a repo file that does not exist | no-mistakes, PRs, and the docs deploy |

No full `nix flake check` runs on pull requests.

## Running them

| Command | Use |
| --- | --- |
| `nix flake check` | Evaluate both hosts and run every check |
| `nix build .#checks.x86_64-linux.<name>` | Run one check |
| `nixos-rebuild build --flake .#<host>` | Build a host without activating it |

New files must be `git add`ed before Nix sees them.

Run `check-imports [repo-root]` after moving Nix modules. It defaults to `/etc/nixos` and reports missing sibling imports, references to nonexistent files, and `default.nix` files outside excluded `_` paths under `modules/`.

## Changing it

| To change | Edit |
| --- | --- |
| The checks | [`modules/flake/checks.nix`](../../modules/flake/checks.nix) |
| Lint rules | [`statix.toml`](../../statix.toml) |
| The comment rule and its message | [`lint/no-comments.yml`](../../lint/no-comments.yml) |
| The comment rule in the agents | [`modules/ai/harness/no-comments.nix`](../../modules/ai/harness/no-comments.nix) |
| PR checks | [`.github/workflows/`](../../.github/workflows) |
