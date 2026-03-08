{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070 | RAM: 64GB | Storage: 2TB NVMe SSD

let
  hardwareConfig = {
    # Controls the monitor layout for hyprland
    workspace = [ "1, monitor:DP-1, default:true" ];
    monitor = [
      "DP-1,2560x1440@239.97,0x0,1,bitdepth,10,vrr,2"
    ];
    # Suspend after 2 hours of idle
    hypridle.suspendTimeout = 7200;
  };
in
{
  imports = [
    ../modules/system/base.nix
    ../modules/desktop
    ../modules/desktop/gaming
    ../modules/desktop/hardware/nvidia.nix
    ../modules/server/ai

    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  # Home-manager configuration with hardware-specific settings
  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
      inherit hardwareConfig;
    };
    users.codyt = {
      home.stateVersion = "25.11";
      imports = [
        ../users/cody/ui.nix
        ../secrets/home-secrets.nix
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "vmd"
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-intel"
    "v4l2loopback"
    "btusb"
  ];

  # Use the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # v4l2loopback for virtual camera in obs
  programs.obs-studio.enableVirtualCamera = true;
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';
  time.hardwareClockInLocalTime = true;

  # Networking
  networking.hostName = "beast"; # Define your hostname.
  networking.networkmanager.enable = true;
  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  networking.useDHCP = lib.mkDefault true;

  # Ensure 14th Gen Intel CPU works correctly
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # System Filesystems
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/8a65acd3-482f-4e10-81c9-d814616564c6";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/36FA-44EF";
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

  # Mount server books directory via NFS (local network)
  fileSystems."/mnt/server-books" = {
    device = "192.168.1.31:/mnt/media/Media/Books";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 65536; # 64GB swap file to handle memory-intensive builds
    }
  ];

  # Renaming the logging client to machine hostname
  services.promtail.configuration.scrape_configs = [
    {
      job_name = "journal";
      journal = {
        max_age = "12h";
        labels = {
          job = "systemd-journal";
          host = "beast";
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

  # Should be the same as the version of NixOS you installed on this machine.
  system.stateVersion = "25.05"; # Did you read the comment?
}
