{ config, pkgs, ... }:

{
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  # Enable VA-API (Video Acceleration API) support for hardware video decoding/encoding on NVIDIA cards and compatibility bridges between VDPAU and VA-API
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
    libva-vdpau-driver
    libvdpau-va-gl
  ];

  # Use EGL for Wayland
  environment.systemPackages = (
    with pkgs;
    [
      egl-wayland
    ]
  );
}
