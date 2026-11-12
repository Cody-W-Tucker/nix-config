# Cody User Configuration

This directory owns Home Manager configuration: shell defaults, desktop session, editor, knowledge tooling, and the local AI/operator harness entry points that run inside the user session.

Use this README as the local map before editing files under `users/cody`. Central docs should point here instead of repeating implementation detail.

## Entry Points

- `core.nix` — shared user account, shell, terminal, browser, navigation, and baseline program configuration.
- `server.nix` — Cody's server-side user profile when a host does not need the desktop stack.
- `desktop.nix` — imports the interactive desktop profile.

## Stack

| Component                 | Tool                                                       | Configuration Location                                                                                                        |
| ------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Shell                     | Zsh, Direnv, FZF, Eza, Bat, Zoxide, Ripgrep, Lazygit       | `core.nix`, `desktop/programs.nix`                                                                                            |
| Terminal                  | Kitty                                                      | `core.nix`, `desktop.nix`                                                                                                     |
| Browsers                  | Zen, Chromium                                              | `desktop/programs.nix`, `desktop/xdg.nix`                                                                                     |
| File and navigation       | Yazi, Eza, Zoxide, FZF, Nautilus                           | `core.nix`, `desktop/programs.nix`, `desktop/default.nix`                                                                     |
| Window manager/compositor | Hyprland                                                   | `desktop/hyprland.nix`, `desktop/hyprland/settings.nix`, `desktop/hyprland/autostart.nix`                                     |
| Launcher                  | Rofi                                                       | `desktop/rofi.nix`, `desktop/packages/scripts/rofi-launcher.nix`, `desktop/packages/scripts/rofi-web-launcher.nix`            |
| Status bar                | Waybar                                                     | `desktop/waybar.nix`                                                                                                          |
| Notifications             | Notification center                                        | `desktop/notifications.nix`                                                                                                   |
| Audio session             | PipeWire                                                   | `desktop/pipewire.nix`                                                                                                        |
| Speech                    | Hold-to-dictate and voice-input pipeline                   | `desktop/speech-to-text.nix`, `desktop/notifications.nix`, `desktop/waybar.nix`                                               |
| Editor                    | NixVim                                                     | `editor/nixvim/default.nix`, `editor/nixvim/keymaps.nix`, `editor/nixvim/plugins/` (the 99 plugin package lives in `plugins/99/`) |
| Knowledge base            | Obsidian                                                   | `desktop/obsidian/default.nix`, `desktop/obsidian/hotkeys.nix`, `desktop/obsidian/plugin-data/`, `desktop/obsidian/snippets/` |
| Knowledge tooling         | QMD skill                                                  | `harness/opencode/agents/knowledge/`                                                                                          |
| AI/operator harness       | OpenCode, Claude Code, MCP, custom tools and skills        | `harness/default.nix`, `harness/mcp.nix`, `harness/opencode/`, `harness/claude-code/`                                         |
| Desktop utilities         | Screenshots, OCR, clipboard, media helpers, file viewers   | `desktop/default.nix`, `desktop/xdg.nix`                                                                                      |
