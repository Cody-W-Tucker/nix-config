# Graphical Aspect

`den.aspects.graphical` is one aspect spread over several files in this directory; each file
owns one concern and may contribute both halves (`nixos` for system plumbing,
`provides.to-users.homeManager` for the user's side). Den merges the contributions, so a host
includes `den.aspects.graphical` once.

- `session.nix`: graphics, gvfs, basic desktop packages, Wayland and NVIDIA session variables.
- `hyprland.nix`: Hyprland (UWSM + greetd), lock screen, idle management and Waybar.
- `launcher.nix`: Rofi, themed from Stylix, and the Wi-Fi picker.
- `notifications.nix`, `xdg.nix`: SwayNC; XDG directories and default applications.
- `theming.nix`: system fonts and Stylix theming (Home Manager only).

Applications live in `modules/apps/`; audio, printing and gaming are standalone features in
`modules/`. A host lists the features it wants (see `modules/hosts/beast.nix`); there is no
desktop role.

- Non-module data and large single-class subtrees (`_hyprland/`, `_waybar/`) are `_`-prefixed
  and imported by their aspect.
- Per-host facts come from the den host (`host.hardwareConfig` for the Hyprland layout).
- Stylix is imported only by `theming.nix`, so `config.lib ? stylix` (checked by
  `modules/shell/shell.nix`) is true only on hosts that include `graphical`.
- Does not own the shared shell/git user environment or the editor (see `modules/shell/`,
  `modules/editor/`).
