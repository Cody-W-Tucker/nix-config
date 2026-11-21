# Neovim (nixvim)

`nvim` (also `vi`, `vim`, `$EDITOR`) on both hosts. The NAS has a lean build for config edits. Beast adds web, Python and Zig language support.

## Keys

`nvim` with no file opens a start screen: `ff` files, `fg` grep, `fo` recent, `-` file manager. Leader is `Space`.

| Keys | Action |
| --- | --- |
| `Space f f` / `f g` / `f b` / `f h` | Find file / grep / buffers / help |
| `Space c d` | Jump to a visited directory (zoxide) |
| `Space -` / `Space = =` | yazi at the file / at the working directory |
| `Space g g` | lazygit |
| `re` / `ca` | Rename / code action |
| `Space k` / `Space j` | Previous / next diagnostic |
| `Space 9 v` | Ask AI about the selection (OpenCode, `opencode-go/hy3`, with `AGENTS.md` as context) |
| `Space 9 s` / `Space 9 x` | AI search / stop all AI requests |
| `Space 9 m` / `Space 9 p` | Pick AI model / provider |

## Languages

| Language support | beast | NAS |
| --- | --- | --- |
| Nix, Bash, Dockerfile, Markdown | ✓ | ✓ |
| CSS, Tailwind, HTML, TypeScript/JavaScript, Astro, Python, Zig | ✓ | |

Saving reformats supported files: Nix and YAML on both hosts, web files and Python on beast. In Nix files, hover and completion show the options of both hosts and of this repo (`codyos.*`). Markdown opens with spell check and rendered headings; pasted images are saved in `assets/`. The gutter marks changed lines, and the current line shows its blame.

## Over SSH

Open the NAS from Kitty with `ssh-`. A yank on the NAS lands in beast's clipboard. A paste from beast asks for Kitty's permission first.

## Changing it

All in [`modules/editor/`](../../modules/editor):

| To change | Edit |
| --- | --- |
| Plugins and options, both hosts | [`_nixvim.nix`](../../modules/editor/_nixvim.nix), or a file in `_plugins/` |
| beast-only additions | [`_plugins/desktop.nix`](../../modules/editor/_plugins/desktop.nix) |
| Language servers | [`_plugins/lsp.nix`](../../modules/editor/_plugins/lsp.nix), or `desktop.nix` for beast |
| Format on save | [`_plugins/conform.nix`](../../modules/editor/_plugins/conform.nix) |
| Keys | [`_keymaps.nix`](../../modules/editor/_keymaps.nix) |
| AI (99) provider and model | [`_plugins/99/default.nix`](../../modules/editor/_plugins/99/default.nix) |
