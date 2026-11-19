# Desktop Aspects

One file per desktop feature, owning both halves where a pair exists: `nixos` for system
plumbing, `provides.to-users.homeManager` for the user's side (Home Manager). `desktop.nix` is the
role aspect and includes the features; gaming and openrazer are opt-in and included by the host.

- Non-module data and large single-class subtrees (`_hyprland/`, `_obsidian/`, `_scripts/`,
  `_waybar/`, `_speech-to-text.nix`) are `_`-prefixed and imported by their aspect.
- Per-host facts come from the den host (`host.hardwareConfig` for the Hyprland layout).
- Theming (Stylix) is Home Manager only and lives in `theming.nix`.
- Does not own the shared shell/git user environment or the editor (see `modules/users/`, `modules/editor/`).
