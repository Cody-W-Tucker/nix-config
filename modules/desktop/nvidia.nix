{ config, pkgs, ... }:
{
  config = {

    # Enable OpenGL
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        vaapiVdpau
        libvdpau-va-gl
      ];
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
}
