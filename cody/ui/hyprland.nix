{ pkgs, lib, config, ... }:

{
  home.packages = with pkgs; [
    hyprnome
  ];

  services.gnome-keyring = {
    enable = true;
    components = [ "secrets" "ssh" ];
  };

  imports = [
    ./hyprland/settings.nix
    ./hyprland/autostart.nix
  ];

  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";

  home.sessionVariables = {
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

  wayland.windowManager.hyprland = {
    enable = true;
    # set the Hyprland and XDPH packages to null to use the ones from the NixOS module
    package = null;
    portalPackage = null;
    systemd.enable = false;
    xwayland.enable = true;
  };
  # Lock screen
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 300; # 5mins.
        ignore_empty_input = true;
      };
      background = lib.mkForce [
        {
          monitor = "";
          path = "screenshot";
          color = "rgba(25, 20, 20, 1.0)";
          blur_passes = 2; # 0 disables blurring
          blur_size = 2;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];
      input-field = lib.mkForce [
        {
          monitor = "";
          size = "200, 50";
          outline_thickness = 3;
          dots_size = 0.33;
          dots_spacing = 0.15;
          dots_center = false;
          dots_rounding = -1;
          outer_color = "rgb(151515)";
          inner_color = "rgb(200, 200, 200)";
          font_color = "rgb(10, 10, 10)";
          fade_on_empty = false;
          fade_timeout = 1000;
          placeholder_text = "<i>Input Password...</i>";
          hide_input = true;
          rounding = -1;
          check_color = "rgb(204, 136, 34)";
          fail_color = "rgb(204, 34, 34)";
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          capslock_color = -1;
          numlock_color = -1;
          bothlock_color = -1;
          invert_numlock = false;
          swap_font_color = false;
        }
      ];
    };
  };
  # Idle management
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 900; # 15min.
          on-timeout = "pidof hyprlock || hyprlock";
        }
        {
          timeout = 1800; # 30min.
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 3600; # 1hr.
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
