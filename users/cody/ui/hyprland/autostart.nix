{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # MUST BE FIRST - Environment setup
      "uwsm finalize" # Initializes WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE

      # Wait for wireplumber to fully initialize before starting bluetooth apps
      "sleep 2 && systemctl --user is-active wireplumber && systemctl --user start blueman-applet" # Bluetooth tray icon

      "uwsm app -- feishin" # Music player
    ];
  };
}
