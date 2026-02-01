{ config, pkgs, ... }:

{
  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
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
    substituters = [
      "https://cache.nixos-cuda.org" # https://wiki.nixos.org/wiki/CUDA#Setting_up_CUDA_Binary_Cache
      "https://cache.flox.dev" # https://discourse.nixos.org/t/nix-flox-nvidia-opening-up-cuda-redistribution-on-nix/69189
    ];
    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
    ];
  };

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
    # Required for Firefox/Zen hardware acceleration with NVIDIA
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };
}
