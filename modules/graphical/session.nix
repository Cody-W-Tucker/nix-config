{ den, ... }:
{
  den.aspects.beast.includes = [ den.aspects.graphical ];

  den.aspects.graphical = {
    nixos =
      { pkgs, ... }:
      {
        hardware.graphics.enable = true;

        services = {
          gvfs.enable = true;
        };

        environment.systemPackages = with pkgs; [
          pavucontrol
          xdg-utils
          usbutils
          seahorse
          gcr_3
        ];

        environment.sessionVariables = {
          LIBVA_DRIVER_NAME = "nvidia";
          NVD_BACKEND = "direct";
          GBM_BACKEND = "nvidia-drm";
          __GLX_VENDOR_LIBRARY_NAME = "nvidia";
          __GL_GSYNC_ALLOWED = "1";
          __GL_VRR_ALLOWED = "0";
          MOZ_DISABLE_RDD_SANDBOX = "1";
        };
      };

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
