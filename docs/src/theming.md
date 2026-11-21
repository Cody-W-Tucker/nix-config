# Theming

Beast's whole desktop follows one theme from [`theming.nix`](../../modules/graphical/theming.nix). Change it there and every app changes at the next `update`. The NAS has no theme.

| | |
| --- | --- |
| Colors | Catppuccin Mocha (dark); apps that follow the system dark-mode preference turn dark |
| UI text | DejaVu Sans / DejaVu Serif |
| Monospace | JetBrains Mono Nerd Font (16 in kitty) |
| Emoji | Noto Color Emoji |
| Cursor | Bibata Modern Classic |
| Icons | Adwaita |
| Wallpaper | [`galaxy-waves.jpg`](../../wallpapers/galaxy-waves.jpg) |

Neovim uses its own Catppuccin theme with the same palette. Waybar, hyprlock, fzf and yazi have custom looks built from the palette. rofi uses its own font with the theme colors.

## Changing it

| To change | Edit |
| --- | --- |
| Scheme, fonts, cursor, wallpaper, opacity | [`theming.nix`](../../modules/graphical/theming.nix) |
| Waybar look | [`_waybar/waybar.nix`](../../modules/graphical/_waybar/waybar.nix) |
| fzf and yazi colors | [`shell.nix`](../../modules/shell/shell.nix) |
| Theme colors in another app | Read `config.lib.stylix.colors`. Outside the desktop files, guard with `lib.mkIf (config.lib ? stylix)`, or the NAS fails to evaluate. |
