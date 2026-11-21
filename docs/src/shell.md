# Shell and Git

zsh on both hosts, with vi mode, history suggestions, direnv and Starship. Some standard commands are replaced by modern tools. Git is preconfigured.

## Commands

| Type | Get |
| --- | --- |
| `cd <part of a path>` | zoxide jump to a visited directory |
| `ls`, `ll` | eza, with icons and Git status |
| `cat` | bat, with syntax colors |
| `rr` | yazi; on quit, the shell is in yazi's last directory |
| `gg` | lazygit |
| `fzf` | Fuzzy finder; `Ctrl-J`/`Ctrl-K` move, preview on the right (default colors on the NAS) |
| A missing command | The name of the package that provides it |

Each open shell keeps its own history; a new shell sees all of it. Deploy commands (`update`, `pullUpdate`, `upgrade`, `gcCleanup`): see [Building and updating](getting-started.md).

## Git

`git pull` rebases. The first `git push` of a branch sets its upstream. `git diff`, `log` and `show` page through delta. `git commit` opens Neovim. `git st` is `git status`. Run `gh auth login` once per host before using `gh`.

## Changing it

| To change | Edit |
| --- | --- |
| Shell, tools, aliases | [`shell.nix`](../../modules/shell/shell.nix) |
| Git | [`git.nix`](../../modules/shell/git.nix) |
