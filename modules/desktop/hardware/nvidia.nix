{
  pkgs,
  ...
}:

{
  imports = [
    ../../hardware/nvidia.nix
  ];

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  environment = {
    # Use EGL for Wayland
    systemPackages = with pkgs; [
      egl-wayland
      nvidia-vaapi-driver
      cudaPackages.cudatoolkit
    ];

    # NVIDIA-specific environment variables
    sessionVariables = {
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

    # Global Electron flags for NVIDIA Wayland — fixes scroll glitches and rendering artifacts (system-wide)
    etc."xdg/electron-flags.conf".text = ''
      --enable-features=UseOzonePlatform,WaylandWindowDecorations,VaapiVideoDecodeLinuxGL
      --ozone-platform-hint=auto
      --disable-gpu-shader-disk-cache
      --enable-features=WaylandLinuxDrmSyncobj
    '';
  };
}
