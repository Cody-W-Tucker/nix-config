{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # MUST BE FIRST - Environment setup
      "uwsm finalize" # Initializes WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE

      # Media app
      "uwsm app -- feishin"
    ];
  };
}
