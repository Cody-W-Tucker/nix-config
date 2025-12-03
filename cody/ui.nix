{ pkgs, lib, ... }:

{
  imports = [
    ./ui
    ./cli
  ];

  # Keyboard
  home.keyboard = {
    layout = "us";
    model = "pc105";
  };

  # Styling and themes
  stylix = {
    enable = true;
    polarity = "dark";
    opacity = {
      applications = 0.9;
      terminal = 0.8;
      desktop = 1.0;
      popups = 1.0;
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    fonts = {
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
    # Wallpaper
    image = ../modules/wallpapers/galaxy-waves.jpg;
  };

  # Since all of my machines use NVIDIA, we can set some common environment variables for graphics and Wayland support.
  home.sessionVariables = {
    # ---------------------------
    # HDR Passthrough Support
    # ---------------------------
    DXVK_HDR = "1";
    ENABLE_HDR_WSI = "1";
    WLR_NO_HARDWARE_CURSORS = "1"; # Fixes NVIDIA cursor issues in HDR
    # ---------------------------
    # Electron and Browser Support
    # ---------------------------

    # Force Electron apps to use X11 backend
    NIXOS_OZONE_WL = 1;

    # Enable Wayland backend for Firefox (and other Mozilla apps)
    MOZ_ENABLE_WAYLAND = "1";
    # Disable RDD sandbox in Mozilla (may help with Nvidia or video decoding issues)
    MOZ_DISABLE_RDD_SANDBOX = "1";

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
    # Nvidia & Graphics Drivers
    # ---------------------------

    # Use Nvidia driver for VA-API (hardware video decoding)
    LIBVA_DRIVER_NAME = "nvidia";
    # Set Nvidia backend for NVDEC/NVENC
    NVD_BACKEND = "direct";
    # Use Nvidia GBM backend for DRM (Direct Rendering Manager)
    GBM_BACKEND = "nvidia-drm";
    # Use Nvidia's GLX implementation
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "1";
    CUDA_CACHE_PATH = "\${HOME}/.cache/nv";

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

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "25.05";
}
