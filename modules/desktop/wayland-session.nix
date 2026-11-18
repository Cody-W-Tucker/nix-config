{
  # Wayland session environment for the user: HDR passthrough, native Wayland for
  # Electron/Mozilla/Qt/GTK/SDL.
  den.aspects.wayland-session.provides.to-users.homeManager.home.sessionVariables = {
    # ---------------------------
    # HDR Passthrough Support
    # ---------------------------
    DXVK_HDR = "1";
    ENABLE_HDR_WSI = "1";
    # ---------------------------
    # Electron and Browser Support
    # ---------------------------

    # Let Electron/Chromium apps use the native Wayland backend
    NIXOS_OZONE_WL = 1;

    # Enable Wayland backend for Firefox (and other Mozilla apps)
    MOZ_ENABLE_WAYLAND = "1";

    # ---------------------------
    # Qt Toolkit Configuration
    # ---------------------------

    # Automatically scale Qt apps based on screen DPI
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    # Use Wayland as the Qt platform
    QT_QPA_PLATFORM = "wayland;xcb";
    # Disable window decorations in Qt on Wayland
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

    # ---------------------------
    # Wayland & Compositor Settings
    # ---------------------------

    # Preferred GDK (GTK) backends (Wayland, fallback to X11)
    GDK_BACKEND = "wayland,x11";
    # SDL (Simple DirectMedia Layer) to use Wayland
    SDL_VIDEODRIVER = "wayland,x11";
    # Use libinput for input devices in wlroots compositors
    WLR_USE_LIBINPUT = "1";
  };
}
