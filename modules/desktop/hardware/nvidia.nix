{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    nvidiaSettings = false;
  };

  # NVIDIA GPU monitoring for Prometheus
  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    port = 9835;
  };

  # Open firewall for NVIDIA GPU exporter
  networking.firewall.allowedTCPPorts = [ 9835 ];

  environment = {
    # Use EGL for Wayland
    systemPackages = with pkgs; [
      egl-wayland
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

  # Build apps with CUDA support
  nixpkgs.config.cudaSupport = true;
  # Also deal with CUDA license
  nixpkgs.config.allowUnfreePredicate =
    p:
    builtins.all (
      license:
      license.free
      || builtins.elem license.shortName [
        "CUDA EULA"
        "cuDNN EULA"
        "cuTENSOR EULA"
        "NVidia OptiX EULA"
      ]
    ) (if builtins.isList p.meta.license then p.meta.license else [ p.meta.license ]);

  # Use substituters to avoid building from source
  nix.settings = {
    extra-substituters = [
      "https://cache.nixos-cuda.org" # https://wiki.nixos.org/wiki/CUDA#Setting_up_CUDA_Binary_Cache
      "https://cache.flox.dev" # https://discourse.nixos.org/t/nix-flox-nvidia-opening-up-cuda-redistribution-on-nix/69189
    ];
    extra-trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };
}
