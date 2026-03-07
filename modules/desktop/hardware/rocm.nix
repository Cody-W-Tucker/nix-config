{ pkgs, ... }:

{
  # Load AMDGPU for Xorg and Wayland.
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Build apps with ROCm support.
  nixpkgs.config.rocmSupport = true;

  hardware.amdgpu = {
    # Load amdgpu as early as possible so the APU comes up cleanly during boot.
    initrd.enable = true;
    # Enable the ROCm OpenCL runtime and ICD loader.
    opencl.enable = true;
  };

  environment.systemPackages = with pkgs; [
    clinfo
    rocminfo
    rocm-smi
    radeontop
  ];

  environment.sessionVariables = {
    # Mesa VA-API driver for modern AMD GPUs.
    LIBVA_DRIVER_NAME = "radeonsi";
  };
}
