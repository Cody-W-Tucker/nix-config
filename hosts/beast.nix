{ config, lib, pkgs, ... }:

{
  imports =
    [
      ../configuration.nix
      ../modules/desktop
      ../modules/desktop/gaming.nix
      ../modules/desktop/hyprland.nix
      ../modules/desktop/nvidia.nix
      ../modules/desktop/mcp-servers.nix
      ../modules/scripts
      ../modules/server/ai.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.initrd.availableKernelModules = [ "vmd" "xhci_pci" "ahci" "nvme" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
  time.hardwareClockInLocalTime = true;

  # Networking
  networking.hostName = "beast"; # Define your hostname.
  networking.networkmanager.enable = true;
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;

  # Use the latest kernel and matching NVIDIA driver
  boot.kernelPackages = pkgs.linuxPackages_latest;
  hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.production;

  # Ensure 14th Gen Intel CPU works correctly
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # System Filesystems
  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/8a65acd3-482f-4e10-81c9-d814616564c6";
      fsType = "ext4";
      options = [ "noatime" ];
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/36FA-44EF";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # Sync configuration for user directories
  services.syncthing = {
    user = "codyt";
    group = "users";
    configDir = "/home/codyt/.config/syncthing";
    settings.folders = {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [ "server" "workstation" ];
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
    options = [ "bind" "nofail" ];
  };

  fileSystems."/home/codyt/Documents" = {
    device = "/mnt/backup/Share/Documents";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/home/codyt/Music" = {
    device = "/mnt/backup/Share/Music";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/home/codyt/Pictures" = {
    device = "/mnt/backup/Share/Pictures";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/home/codyt/Videos" = {
    device = "/mnt/backup/Share/Videos";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/home/codyt/Sync/Cody-Obsidian" = {
    device = "/mnt/backup/Share/Documents/Personal";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  swapDevices = [ ];

  # Renaming the logging client to machine hostname
  services.promtail.configuration.scrape_configs = [{
    job_name = "journal";
    journal = {
      max_age = "12h";
      labels = {
        job = "systemd-journal";
        host = "beast";
      };
    };
    relabel_configs = [{
      source_labels = [ "__journal__systemd_unit" ];
      target_label = "unit";
    }];
  }];

  # Machine specific packages
  environment.systemPackages =
    (with pkgs; [
      rofi-network-manager
      kdePackages.kdenlive
    ]);

  # Should be the same as the version of NixOS you installed on this machine.
  system.stateVersion = "25.05"; # Did you read the comment?
}
