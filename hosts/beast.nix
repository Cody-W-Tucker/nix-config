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
    ../modules/desktop
    ../modules/desktop/tailscale.nix
    ../modules/desktop/gaming.nix
    ../modules/desktop/hyprland.nix
    ../modules/desktop/nvidia.nix
    ../modules/desktop/mcp-servers.nix
    ../modules/desktop/razer.nix
    ../modules/scripts
    ../modules/server/ai.nix

    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

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

  fileSystems."/home/codyt/Knowledge/Personal" = {
    device = "/mnt/backup/Obsidian";
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
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

  # Machine specific packages
  environment.systemPackages = (
    with pkgs;
    [
      rofi-network-manager
      kdePackages.kdenlive
      prismlauncher
    ]
  );

  # Should be the same as the version of NixOS you installed on this machine.
  system.stateVersion = "25.05"; # Did you read the comment?
}
