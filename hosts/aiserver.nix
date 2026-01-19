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
    ../modules/desktop/printing.nix
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

  # Sync configuration for user directories
  services.syncthing = {
    user = "codyt";
    group = "users";
    configDir = "/home/codyt/.config/syncthing";
    settings.folders = {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [
          "server"
          "beast"
        ];
      };
      "Cody's Obsidian" = {
        path = "/home/codyt/Sync/Cody-Obsidian";
        devices = [ "Cody's Pixel" ];
      };
    };
  };

  # User home directories
  fileSystems."/home/codyt/Records" = {
    device = "/mnt/backup/Share/Records";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Documents" = {
    device = "/mnt/backup/Share/Documents";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Music" = {
    device = "/mnt/backup/Share/Music";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Pictures" = {
    device = "/mnt/backup/Share/Pictures";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Videos" = {
    device = "/mnt/backup/Share/Videos";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  fileSystems."/home/codyt/Sync/Cody-Obsidian" = {
    device = "/mnt/backup/Share/Documents/Personal";
    fsType = "none";
    options = [
      "bind"
      "nofail"
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

  # AMD-specific environment variables
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    GBM_BACKEND = "radeonsi";
    VDPAU_DRIVER = "radeonsi";
  };

  # Provisionary ai chat interface TODO: Should remove later
  services.open-webui = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
  };

  services.ollama = {
    enable = true;
    rocmOverrideGfx = "11.0.0";
  };

  system.stateVersion = "25.11"; # Don't change
}
