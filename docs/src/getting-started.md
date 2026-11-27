# Building and updating

Ask an agent to make the change. It works on a branch, opens a pull request, and merges it when you say so. Then run `update`. For a small change, ask for it on main instead. The agent commits without pushing, and `update` pushes it.

## Deploy

| Command        | Result                                                                          |
| -------------- | ------------------------------------------------------------------------------- |
| `update`         | Pulls `main`, runs the lint checks, switches beast, then pushes a local commit if there is one. |
| `update --nas`   | Switches beast, then the NAS over SSH                                           |

`update` refuses when `/etc/nixos` has uncommitted changes or is not on `main`. See [Checks and standards](checks.md). If the switch fails, nothing is pushed. `update --nas` also deploys to the NAS after the push. The NAS step stops if its checkout has uncommitted changes or cannot fast-forward.

## Other commands

| Command    | Use                                                                          |
| ---------- | ---------------------------------------------------------------------------- |
| `upgrade`    | Update all flake inputs and switch this host                                 |
| `gcCleanup`  | Free disk. Deletes every old generation, so there is nothing to roll back to. |

## What runs without you

| When         | What happens                                                                                                                                                                                                                  |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ~03:00 daily | The NAS builds both hosts from `main` and switches itself to `main`. The next `update` on beast downloads instead of compiling. Uncommitted edits on the NAS are not included. Log: `journalctl -u nightly-build` on the NAS. |
| Sunday       | A GitHub pull request `update/flake-lock` updates the flake inputs                                                                                                                                                            |
| Weekly       | Generations older than 7 days are deleted                                                                                                                                                                                     |
