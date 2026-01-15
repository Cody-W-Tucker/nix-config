{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../configuration.nix
    # Using community hardware nixosConfigurations
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    ../modules/desktop
    ../modules/desktop/tailscale.nix
    ../modules/desktop/hyprland.nix
    ../modules/desktop/razer.nix
    ../modules/scripts
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

  hardware = {
    graphics.extraPackages = with pkgs; [
      rocmPackages.clr.icd
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ];
    amdgpu = {
      opencl.enable = true; # Enables ROCm-based OpenCL
      initrd.enable = true; # Loads amdgpu in initrd for early detection
    };

  };

  services.ollama = {
    package = pkgs.ollama-rocm;
  };

  system.stateVersion = "25.11"; # Don't change
}
