# Cody User Configuration

This directory owns the `codyt` user aspect: the account and the Home Manager profile shared by every host. Desktop-session pieces live in `modules/desktop/`, the editor in `modules/editor/nixvim/`, and the local AI/operator harness in `modules/harness/`.

## Entry Points

- `codyt.nix` — user account (`user` class) and Home Manager profile; includes the aspects below.
- `shell.nix` — zsh, fzf, yazi, eza, bat, zoxide, direnv (`user-shell`). Stylix colors for fzf/yazi apply only where the theming aspect imports Stylix (beast).
- `git.nix` — git, delta, GitHub CLI, lazygit (`user-git`).
- `cli-tools.nix` — small CLI packages, ripgrep and `$VISUAL` (`user-cli-tools`).

## Stack

| Component                 | Tool                                                 | Configuration Location                                    |
| ------------------------- | ---------------------------------------------------- | --------------------------------------------------------- |
| Shell                     | Zsh, Direnv, FZF, Eza, Bat, Zoxide, Ripgrep, Lazygit | `shell.nix`, `git.nix`, `cli-tools.nix`, `modules/desktop/programs.nix` |
| Terminal                  | Kitty                                                | `modules/desktop/terminal.nix`                            |
| Editor                    | NixVim                                               | `modules/editor/nixvim/nixvim.nix`, `_nixvim.nix`, `_keymaps.nix`, `_plugins/` (the 99 plugin package lives in `_plugins/99/`; desktop-only plugins in `desktop.nix`) |
| Knowledge tooling         | QMD MCP                                              | `modules/harness/_hm/mcp.nix`                             |
| AI/operator harness       | OpenCode, Claude Code, MCP, custom tools and skills  | `modules/harness/harness.nix`, `modules/harness/_hm/`      |
| Desktop session           | Hyprland, Rofi, Waybar, Obsidian, speech, …          | `modules/desktop/`                                        |
