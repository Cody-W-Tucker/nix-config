# Checks and standards

The repo enforces its standards with flake checks. `update` runs every check below except `docs` itself; GitHub runs them on every pull request.

## What is checked

| Check | Fails on | Runs in |
| --- | --- | --- |
| `formatting` | Nix not formatted with nixfmt. `nix fmt` corrects it. | `update`, PRs |
| `imports` | A `default.nix` outside a `_` path under `modules/`, or a `_` subtree whose `default.nix` misses a sibling or imports a missing file | `update`, PRs |
| `statix`, `deadnix` | Lint warnings, unused bindings | `update`, PRs |
| `no-comments` | Any Nix comment. `ast-grep scan --update-all .` then `nix fmt` deletes them. OpenCode, Claude Code and Neovim show the same error as you type. | `update`, PRs |
| `docs` | This book does not build, or links a repo file that does not exist | PRs, and the docs deploy |

On a pull request, the full `nix flake check` runs only when the `NIX_SECRETS_READ` token is available; without it, only formatting and lint run.

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
| The comment rule in the agents | [`modules/harness/_hm/plugins/no-comments/default.nix`](../../modules/harness/_hm/plugins/no-comments/default.nix) |
| PR checks | [`.github/workflows/`](../../.github/workflows) |
