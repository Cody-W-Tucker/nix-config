# Building and updating

Edit `/etc/nixos` on beast, then deploy with `update`.

## Deploy

| Command                   | Result                                                  |
| ------------------------- | ------------------------------------------------------- |
| `update "commit message"` | Formats and checks the tree, then commits, switches and pushes. |
| `update --nas`            | Switches beast, then the NAS over SSH                   |

See [Checks and standards](checks.md). If the switch fails, the commit stays local and nothing is pushed. `update --nas "commit message"` also deploys to the NAS after the push. The NAS step stops if its checkout has uncommitted changes or cannot fast-forward.

## Other commands

| Command      | Use                                                                           |
| ------------ | ----------------------------------------------------------------------------- |
| `pullUpdate` | Apply commits pushed from the other host                                      |
| `upgrade`    | Update all flake inputs and switch this host                                  |
| `gcCleanup`  | Free disk. Deletes every old generation, so there is nothing to roll back to. |

## What runs without you

| When         | What happens                                                                                                                                                                                                                  |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ~03:00 daily | The NAS builds both hosts from `main` and switches itself to `main`. The next `update` on beast downloads instead of compiling. Uncommitted edits on the NAS are not included. Log: `journalctl -u nightly-build` on the NAS. |
| Sunday       | A GitHub pull request `update/flake-lock` updates the flake inputs                                                                                                                                                            |
| Weekly       | Generations older than 7 days are deleted                                                                                                                                                                                     |
