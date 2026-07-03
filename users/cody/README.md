# Cody User Configuration

This directory owns Cody's Home Manager configuration: shell defaults, desktop session, editor, knowledge tooling, and the local AI/operator harness entry points that run inside the user session.

Use this README as the local map before editing files under `users/cody`. Central docs should point here instead of repeating implementation detail.

## Entry Points

- `core.nix` — shared user account, shell, terminal, browser, navigation, and baseline program configuration.
- `server.nix` — Cody's server-side user profile when a host does not need the desktop stack.
- `desktop.nix` — imports the interactive desktop profile.
- `desktop/default.nix` — desktop Home Manager root. It assembles Hyprland, Waybar, editor, Obsidian, speech, notifications, packages, XDG, and harness modules.
- `desktop/harness/README.md` — local owner for OpenCode, Herdr, MCP, tools, skills, and agent harness details.

## Shell, Programs, and Files

Primary files:

- `core.nix`
- `desktop/programs.nix`
- `desktop/xdg.nix`
- `desktop/packages/scripts/*.nix`

Operator notes:

- Keep common CLI/user behavior in `core.nix` unless it only makes sense inside the graphical desktop.
- Put desktop applications, MIME routing, user directories, and browser/app associations in the desktop layer.
- Add small custom launchers under `desktop/packages/scripts/`; they are user-facing tools, not system services.
- Keep file names lowercase kebab-case and match package names where practical.

Current program shape:

- Zsh and aliases live with the user baseline.
- Kitty, Yazi, FZF/Bat integrations, Zen/Chromium browser handling, and XDG MIME defaults are desktop-owned.
- Rofi launchers and `focus-or-run` support the Hyprland workflow and should stay near the desktop packages/scripts area.

## Desktop Session

Primary files:

- `desktop/default.nix`
- `desktop/hyprland.nix`
- `desktop/hyprland/settings.nix`
- `desktop/hyprland/autostart.nix`
- `desktop/waybar.nix`
- `desktop/notifications.nix`
- `desktop/pipewire.nix`
- `desktop/speech-to-text.nix`

The system-level Hyprland module enables the compositor/session plumbing. Cody's behavior lives here in Home Manager.

Edit pattern:

- Put compositor services, idle/lock behavior, and Hyprland-adjacent daemons in `desktop/hyprland.nix`.
- Put bindings, window rules, workspaces, monitor-derived settings, animation, and layout in `desktop/hyprland/settings.nix`.
- Put startup commands in `desktop/hyprland/autostart.nix`.
- Put bar modules and custom status commands in `desktop/waybar.nix`.
- Put notification center behavior in `desktop/notifications.nix`.
- Put audio session tweaks in `desktop/pipewire.nix`.
- Put hold-to-dictate and speech pipeline scripts in `desktop/speech-to-text.nix`.

Important workflows:

- Hyprland uses host-provided `hardwareConfig` for monitor and suspend behavior. Do not hard-code host-specific display assumptions in generic desktop files.
- Special workspaces carry the daily operating model: AI, development, media, and other scratchpad-style contexts.
- `focus-or-run` helpers should remain the preferred pattern for keybindings that either focus an existing app or launch one.
- Hold-to-dictate is bound through Hyprland and implemented in `speech-to-text.nix`; keep model/API details there so the keybinding stays readable.
- Waybar custom modules should call stable user tools/scripts and avoid embedding long shell logic inline.

## Editor: NixVim

Primary files:

- `desktop/editor/nixvim/default.nix`
- `desktop/editor/nixvim/keymaps.nix`
- `desktop/editor/nixvim/plugins/*.nix`

NixVim is the declarative Neovim owner for this user. The plugin directory keeps behavior split by concern: LSP, completion, formatting, treesitter, Telescope, statusline, startup, and local AI/editor integrations.

Edit pattern:

- Add keybindings in `keymaps.nix` unless they are tightly coupled to one plugin module.
- Add language server, formatter, and completion behavior to the matching plugin module.
- Keep project/agent-specific editor glue in its own plugin file rather than hiding it inside the core editor defaults.
- Do not suppress type or Nix evaluation errors; fix the option shape or module wiring.

## Obsidian Knowledge Base

Primary files:

- `desktop/obsidian/default.nix`
- `desktop/obsidian/hotkeys.nix`
- `desktop/obsidian/plugin-data/*.json`
- `desktop/obsidian/snippets/*.css`

The Obsidian config is declarative Home Manager state for Cody's knowledge base. It manages vault definitions, plugins, plugin settings, hotkeys, CSS snippets, and the desktop entry used to open the primary vault.

Operational shape:

- `~/Knowledge/Personal` is the primary working vault.
- `~/Knowledge/Base` is the lighter reference/base vault.
- Plugin settings that are naturally JSON stay under `plugin-data/` and are imported by Nix.
- Hotkeys stay in `hotkeys.nix` so the main module remains readable.
- CSS snippets stay in `snippets/` and should remain small and purpose-named.
- Agent-facing Obsidian behavior should keep stable paths and predictable note formats; do not move vault paths casually.

## AI/User Harness Boundary

The desktop imports the user harness from `desktop/harness`. That subtree owns OpenCode, Herdr, local MCP configuration, agent skills, and custom OpenCode tools. See `desktop/harness/README.md` before changing harness internals.

Rule of thumb:

- If the change affects Cody's general desktop or user account, document it here.
- If the change affects agent execution, OpenCode, Herdr, MCP servers, tools, skills, or per-agent configuration, document it in the harness README.

## Change Checklist

- Keep implementation detail in local READMEs near the code owner.
- Keep central `docs/` pages short: purpose, owner, and pointers.
- Add new files to git before relying on flakes to see them.
- For small Home Manager edits, a rebuild is usually enough; dry-run only when changing services, module wiring, or unfamiliar Nix patterns.
