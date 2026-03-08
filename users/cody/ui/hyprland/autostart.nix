{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      # MUST BE FIRST - Environment setup
      "uwsm finalize" # Initializes WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE

      "uwsm app -- feishin" # Music player
      "systemctl --user start blueman-applet" # Bluetooth tray icon
    ];
  };
}
