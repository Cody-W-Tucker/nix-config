{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.graphical ];

  # The graphical session on a workstation: the machine-level desktop plumbing (graphics,
  # gvfs, basic desktop packages), the Wayland session environment, and the NVIDIA session
  # variables. One aspect, `graphical`, spans this directory: session.nix, hyprland.nix (+
  # waybar), launcher.nix (rofi, Wi-Fi picker), notifications.nix, xdg.nix and theming.nix.
  den.aspects.graphical = {
    nixos =
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
    provides.to-users.homeManager.home.sessionVariables = {
      DXVK_HDR = "1";
      ENABLE_HDR_WSI = "1";
      NIXOS_OZONE_WL = 1;
      MOZ_ENABLE_WAYLAND = "1";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      GDK_BACKEND = "wayland,x11";
      SDL_VIDEODRIVER = "wayland,x11";
      WLR_USE_LIBINPUT = "1";
    };
  };
}
