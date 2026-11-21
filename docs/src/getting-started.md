# Building and updating

Edit `/etc/nixos` on beast, then deploy with `update`.

## Deploy

| Command | Result |
| --- | --- |
| `update` | Prompts for a commit message, then switches beast and pushes |
| `update "msg"` | The same, with the message inline |
| `update --nas` | Switches beast, then the NAS over SSH |

`update` commits everything in `/etc/nixos`, so move or ignore files you do not want committed. It formats and checks the tree first; see [Checks and standards](checks.md). If the switch fails, the commit stays local and nothing is pushed: correct the error and run `update` again. `--nas` stops if the NAS checkout has uncommitted changes.

## Other commands

| Command | Use |
| --- | --- |
| `pullUpdate` | Apply commits pushed from the other host |
| `upgrade` | Update all flake inputs and switch this host |
| `gcCleanup` | Free disk. Deletes every old generation, so there is nothing to roll back to. |

## What runs without you

| When | What happens |
| --- | --- |
| ~03:00 daily | The NAS builds both hosts from `main` and switches itself to `main`. The next `update` on beast downloads instead of compiling. Uncommitted edits on the NAS are not included. Log: `journalctl -u nightly-build` on the NAS. |
| Sunday | A GitHub pull request `update/flake-lock` updates the flake inputs |
| Weekly | Generations older than 7 days are deleted |
