{ lib, pkgs, ... }:

let
  rocmSmi = pkgs.symlinkJoin {
    name = "rocm-smi";
    paths = [ pkgs.rocmPackages.rocm-smi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rocm-smi \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.libdrm ]}
    '';
  };
in

{
  # Load AMDGPU for Xorg and Wayland.
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Build apps with ROCm support.
  nixpkgs.config.rocmSupport = true;
  nixpkgs.config.rocmTargets = [ "gfx1151" ]; # Target your specific RDNA 3.5 cores

  hardware.amdgpu = {
    # Load amdgpu as early as possible so the APU comes up cleanly during boot.
    initrd.enable = true;
    # Enable the ROCm OpenCL runtime and ICD loader.
    opencl.enable = true;
  };

  environment.systemPackages = with pkgs; [
    clinfo
    libva-utils
    rocmPackages.rocminfo
    rocmSmi
    radeontop
    vulkan-tools
  ];

  environment.sessionVariables = {
    # Mesa VA-API driver for modern AMD GPUs.
    LIBVA_DRIVER_NAME = "radeonsi";
    HSA_OVERRIDE_GFX_VERSION = "11.5.1"; # Ensure runtime compatibility
  };

  nix.settings = {
    extra-substituters = [
      "https://nixos-rocm.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-rocm.cachix.org-1:V9fD90S5pcf8uTf3Yy2FvovPsnz7hA0/Ysh92Vf2k7E="
    ];
  };
}
