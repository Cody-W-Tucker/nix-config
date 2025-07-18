{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # MUST BE FIRST - Environment setup
      "uwsm finalize" # Initializes WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE

      # Workspace-specific apps
      "[workspace 3 silent] uwsm app -- obsidian --enable-features=WaylandLinuxDrmSyncobj"
      "uwsm app -- feishin"
    ];
  };
}
