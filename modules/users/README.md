# Cody User Configuration

This directory owns the `codyt` user aspect: the account and the Home Manager profile shared by every host. Desktop-session pieces live in `modules/graphical/` and `modules/apps/`, the editor in `modules/editor/`, and the local AI/operator harness in `modules/harness/`.

## Entry Points

- `codyt.nix` — user account (`user` class) and Home Manager profile; the editor and harness aspects register themselves on every host via `den.default` (`modules/editor/nixvim.nix`, `modules/harness/harness.nix`). Shell, git and CLI tools live in `modules/shell/` and register on every host via `den.default`.

## Stack

| Component                 | Tool                                                 | Configuration Location                                    |
| ------------------------- | ---------------------------------------------------- | --------------------------------------------------------- |
| Shell                     | Zsh, Direnv, FZF, Eza, Bat, Zoxide, Ripgrep, Lazygit | `modules/shell/shell.nix`, `modules/shell/git.nix`, `modules/apps/apps.nix` |
| Terminal                  | Kitty                                                | `modules/apps/terminal.nix`                            |
| Editor                    | NixVim                                               | `modules/editor/nixvim.nix`, `_nixvim.nix`, `_keymaps.nix`, `_plugins/` (the 99 plugin package lives in `_plugins/99/`; desktop-only plugins are `den.aspects.nixvim.desktop` in `nixvim.nix`) |
| Knowledge tooling         | QMD MCP                                              | `modules/harness/_hm/mcp.nix`                             |
| AI/operator harness       | OpenCode, Claude Code, MCP, custom tools and skills  | `modules/harness/harness.nix`, `modules/harness/_hm/`      |
| Desktop session           | Hyprland, Rofi, Waybar, Obsidian, speech, …          | `modules/graphical/`, `modules/apps/`                  |
