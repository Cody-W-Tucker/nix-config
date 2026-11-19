{
  # The graphical session on a workstation: the machine-level desktop plumbing (graphics,
  # gvfs, basic desktop packages), the Wayland session environment, and the NVIDIA session
  # variables. One aspect, `graphical`, spans this directory: session.nix, hyprland.nix (+
  # waybar), launcher.nix (rofi, Wi-Fi picker), notifications.nix, xdg.nix and theming.nix.
  # The host includes `den.aspects.graphical`; there is no desktop role.
  den.aspects.graphical.nixos =
    { pkgs, ... }:
    {
      hardware.graphics.enable = true;

      services = {
        # Allows nautilus (gnome files) to access gvfs mounts (trash and samba shares)
        gvfs.enable = true;
      };

      # Install basic desktop environment packages that I want on all my systems.
      environment.systemPackages = with pkgs; [
        pavucontrol # PulseAudio volume control
        xdg-utils # xdg-open
        usbutils # For listing USB devices
        seahorse # GNOME keyring manager
        gcr_3 # GNOME Keyring unlock prompt provider
      ];

      # Wayland session variables for NVIDIA GPUs. Pairs with den.aspects.nvidia
      # (modules/hardware/nvidia.nix); this tree is only used on hosts with an NVIDIA GPU (beast).
      environment.sessionVariables = {
        # ---------------------------
        # Nvidia & Graphics Drivers
        # ---------------------------
        LIBVA_DRIVER_NAME = "nvidia";
        NVD_BACKEND = "direct";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __GL_GSYNC_ALLOWED = "1";
        __GL_VRR_ALLOWED = "0";
        # Required for Firefox/Zen hardware acceleration with NVIDIA
        MOZ_DISABLE_RDD_SANDBOX = "1";
      };
    };

  # Wayland session environment for the user: HDR passthrough, native Wayland for
  # Electron/Mozilla/Qt/GTK/SDL.
  den.aspects.graphical.provides.to-users.homeManager.home.sessionVariables = {
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
