{ config, ... }:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "uwsm app -- swaync"
      "uwsm app -- wl-clipboard-history -t"
      "uwsm app -- wl-paste --watch cliphist store"
      ''rm "$HOME/.cache/cliphist/db"'' # Clear clipboard history on startup
      "systemctl --user enable --now hypridle.service"
      "systemctl --user enable --now hyprpaper.service"
      "systemctl --user enable --now waybar.service"
      "[workspace 1 silent ] uwsm app -- obsidian"
      "[workspace 2 silent ] uwsm app -- todoist-electron --ozone-platform-hint=auto"
      "uwsm app -- ferdium"
      "[workspace special silent] uwsm app -- spotube"
    ];
  };
}
