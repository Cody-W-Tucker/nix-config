{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  rocmEnv = pkgs.symlinkJoin {
    name = "rocm-combined";
    paths = with pkgs.rocmPackages; [
      clr
      hipblas
      rocblas
      rocminfo
    ];
  };
in

{
  imports = [
    ../configuration.nix
    # Using community hardware nixosConfigurations
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    ../modules/desktop
    ../modules/desktop/hardware/razer.nix
    ../modules/scripts
  ];

  nixpkgs.config.rocmSupport = true;

  hardware.amdgpu = {
    # Load amdgpu as early as possible so the APU comes up cleanly during boot.
    initrd.enable = true;
    # NixOS wires this to the ROCm OpenCL runtime (`clr` + ICD loader).
    opencl.enable = true;
  };

  # Bootloader
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelParams = [ "amd_pstate=active" ];

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
    ];
    kernelModules = [
      "kvm-amd"
    ];
  };

  networking = {
    hostName = "aiserver";
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

  # User home directories
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

  fileSystems."/home/codyt/Knowledge/Personal" = {
    device = "/mnt/backup/Obsidian";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  users.users.codyt.extraGroups = [
    "render"
    "video"
  ];

  environment.defaultPackages = [ pkgs.lmstudio ];

  environment.systemPackages = with pkgs; [
    clinfo
    rocmPackages.rocminfo
    vulkan-tools
  ];

  environment.variables = {
    # The AI server in `flake.nix` is the GMKtec EVO-X2 with the Ryzen AI Max+ 395
    # Strix Halo APU. AMD's ROCm docs list that APU as gfx1151 and only add official
    # Ryzen APU Linux support in ROCm 7.2. This repo currently evaluates ROCm 7.1.1,
    # so prefer the Mesa RADV Vulkan stack for user-facing inference apps.
    AMD_VULKAN_ICD = "RADV";

    # Many HIP/ROCm tools assume a conventional `/opt/rocm` layout. Expose that path
    # explicitly so build scripts and binary packages can find the runtime on NixOS.
    HIP_PATH = "/opt/rocm";
    ROCM_PATH = "/opt/rocm";
  };

  systemd.tmpfiles.rules = [
    "L+ /opt/rocm - - - - ${rocmEnv}"
  ];

  # Open port for LMstudio
  networking.firewall.allowedTCPPorts = [ 1234 ];

  # Renaming the logging client to machine hostname
  services.promtail.configuration.scrape_configs = [
    {
      job_name = "journal";
      journal = {
        max_age = "12h";
        labels = {
          job = "systemd-journal";
          host = "aiserver";
        };
      };
      relabel_configs = [
        {
          source_labels = [ "__journal__systemd_unit" ];
          target_label = "unit";
        }
      ];
    }
  ];

  system.stateVersion = "25.11"; # Don't change
}
