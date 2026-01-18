{ config, pkgs, ... }:

{
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  nixpkgs.config.cudaSupport = true;

  # Enable VA-API (Video Acceleration API) support for hardware video decoding/encoding on NVIDIA cards and compatibility bridges between VDPAU and VA-API
  hardware.graphics.extraPackages = with pkgs; [
    nvidia-vaapi-driver
    libva-vdpau-driver
    libvdpau-va-gl
  ];

  # Use EGL for Wayland
  environment.systemPackages = with pkgs; [
    egl-wayland
  ];

  # NVIDIA-specific environment variables
  environment.sessionVariables = {
    # ---------------------------
    # Nvidia & Graphics Drivers
    # ---------------------------
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "1";
    CUDA_CACHE_PATH = "\${HOME}/.cache/nv";
    WLR_NO_HARDWARE_CURSORS = "1"; # Fixes NVIDIA cursor issues in HDR
  };
}
