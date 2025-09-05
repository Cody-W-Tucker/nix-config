{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # MUST BE FIRST - Environment setup
      "uwsm finalize" # Initializes WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE

      "uwsm app -- obsidian --enable-features=WaylandLinuxDrmSyncobj"
      # Media app
      "uwsm app -- feishin"
    ];
  };
}
