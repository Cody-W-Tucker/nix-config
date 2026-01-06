{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ../configuration.nix
  ];

  # Bootloader
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # Use newest kernel
    kernelPackages = pkgs.linuxPackages_latest;

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "sdhci_pci"
      "amdgpu"
    ];
    initrd.kernelModules = [ "amdgpu" ];
    kernelModules = [
      "kvm-amd"
      "amdgpu"
    ];
    extraModulePackages = [ ];
    kernelParams = [ "amdgpu.dc=1" ];
  };

  networking = {
    hostName = "ai_server";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/73998e5d-b64f-4148-bacb-af7b7883746a";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BD3E-2CD9";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  hardware.graphics.enable = true;

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ];
  };

  hardware.amdgpu = {
    opencl.enable = true; # Enables ROCm-based OpenCL
    initrd.enable = true; # Loads amdgpu in initrd for early detection
  };

  environment.systemPackages = with pkgs; [
    rocmPackages.clr
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
  ];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
  };

  systemd.services.ollama.serviceConfig.Environment = [
    "HSA_OVERRIDE_GFX_VERSION=11.0.0"
    "HIP_VISIBLE_DEVICES=0"
  ];

  system.stateVersion = "25.11"; # Did you read the comment?

}
