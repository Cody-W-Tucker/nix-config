# Graphical aspect

`den.aspects.graphical` is one aspect spread over this directory. Each file owns one concern and may contribute both `nixos` and `provides.to-users.homeManager`. `session.nix` includes it on beast.

- `session.nix`: graphics, gvfs, basic desktop packages, Wayland and NVIDIA session variables.
- `hyprland.nix`: Hyprland (UWSM + greetd), lock screen, idle and Waybar. `hyprland-settings.nix`: keybinds, window rules, animations, and monitors and workspaces from `host.hardwareConfig`.
- `launcher.nix`: Rofi and the Wi-Fi picker. `notifications.nix`: SwayNC. `xdg.nix`: XDG directories and default apps.
- `theming.nix`: fonts and Stylix. Only this file imports Stylix, so `config.lib ? stylix` (read in `modules/shell/shell.nix`) is true only on hosts with `graphical`.
- `_hyprland/` (the hyprnome patch), `_waybar/` and `_scripts/` are imported by their aspect.

Applications are in `modules/apps/`. Audio, printing and gaming are their own features; there is no desktop role aspect.
