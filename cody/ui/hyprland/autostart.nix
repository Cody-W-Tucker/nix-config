{ config, ... }:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # MUST BE FIRST - Environment setup
      "uwsm finalize" # Initializes WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE

      # Systemd services that require the above variables
      "systemctl --user enable --now hypridle.service"
      "systemctl --user enable --now hyprpaper.service"

      # Clipboard (requires WAYLAND_DISPLAY)
      "uwsm app -- wl-clipboard-history -t"
      "uwsm app -- wl-paste --watch cliphist store"
      ''rm "$HOME/.cache/cliphist/db"''

      # GUI Apps (needs DBUS_SESSION_BUS_ADDRESS from finalize)
      "uwsm app -- swaync"

      # Workspace-specific apps
      "[workspace 1 silent] uwsm app -- obsidian"
      "[workspace 2 silent] uwsm app -- todoist-electron --ozone-platform-hint=auto"
      "uwsm app -- ferdium"
      "[workspace special silent] uwsm app -- spotube"
    ];
  };

}
