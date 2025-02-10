{ config, ... }:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # MUST BE FIRST - Environment setup
      "uwsm finalize" # Initializes WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE

      # Systemd services that require the above variables
      "systemctl --user enable --now hypridle.service"
      "systemctl --user enable --now hyprpaper.service"

      # Clipboard
      ''rm "$HOME/.cache/cliphist/db"''

      # Workspace-specific apps
      "[workspace 1 silent] uwsm app -- obsidian"
      "[workspace 2 silent] uwsm app -- todoist-electron --ozone-platform-hint=auto"
      "uwsm app -- ferdium"
      "[workspace special silent] uwsm app -- spotube"
    ];
  };

}
