{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  hardwareConfig = {
    # Controls the monitor layout for hyprland
    workspace = [ "1, monitor:DP-1, default:true" ];
    monitor = [
      # Samsung Odyssey G65B exposes 2560x1440@239.97; keep SDR desktop output in sRGB and leave HDR to fullscreen-capable clients.
      "DP-1,2560x1440@239.97,0x0,1,vrr,2,bitdepth,10,cm,srgb"
    ];
    # Suspend after 1 hour of idle
    hypridle.suspendTimeout = 3600;
  };

in
{
  imports = [
    # Shared modules
    ../../modules/system/base.nix
    ../../modules/hardware/baseline.nix
    ../../modules/desktop
    ../../modules/desktop/gaming
    ../../modules/desktop/hardware/nvidia.nix
    ../../modules/services/docker.nix

    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  # ── Machine ─────────────────────────────────────────────────
  # Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070 | Storage: 2TB NVMe

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    initrd.availableKernelModules = [
      "vmd"
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = [
      "kvm-intel"
      "btusb"
    ];
    extraModprobeConfig = ''
      options mt7925e disable_aspm=Y
      options btusb enable_autosuspend=n reset=1
    '';
  };

  # ── Drives ──────────────────────────────────────────────────
  environment.systemPackages = [ pkgs.nfs-utils ];

  # System fileSystems
  fileSystems = {
    # Actual drives
    "/" = {
      device = "/dev/disk/by-uuid/8a65acd3-482f-4e10-81c9-d814616564c6";
      fsType = "ext4";
      options = [ "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/36FA-44EF";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
    # Since we use syncthing to keep cody's home dirs synced we map these drives one by one.
    "/home/codyt/Documents" = {
      device = "/mnt/backup/Share/Documents";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
    "/home/codyt/Music" = {
      device = "/mnt/backup/Share/Music";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
    "/home/codyt/Pictures" = {
      device = "/mnt/backup/Share/Pictures";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };
    "/home/codyt/Videos" = {
      device = "/mnt/backup/Share/Videos";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ];
    };

    # NFS mounts from NAS
    "/home/codyt/Projects" = {
      device = "192.168.1.2:/mnt/projects";
      fsType = "nfs";
      options = [
        "noatime"
        "nofail"
        "x-systemd.automount"
        "x-systemd.requires=network-online.target"
      ];
    };
    "/home/codyt/Knowledge" = {
      device = "192.168.1.2:/mnt/knowledge";
      fsType = "nfs";
      options = [
        "noatime"
        "nofail"
        "x-systemd.automount"
        "x-systemd.requires=network-online.target"
      ];
    };

  };
  # Networking
  networking = {
    hostName = "beast";
    networkmanager.enable = true;
    networkmanager.settings.connection = {
      # MT7925 Bluetooth is more stable when NetworkManager does not power-save Wi-Fi.
      "wifi.powersave" = 2;
    };
    useDHCP = lib.mkDefault true; # Enables DHCP on each ethernet and wireless interface.
    interfaces.eno1.wakeOnLan = {
      enable = true;
      policy = [ "magic" ];
    };
  };

  services.fluent-bit.settings.pipeline.inputs = [
    {
      name = "systemd";
      tag = "journal";
      read_from_tail = true;
      strip_underscores = true;
      lowercase = true;
    }
  ];

  # Should be the same as the version of NixOS you installed on this machine.
  system.stateVersion = "25.05"; # Did you read the comment?

  # Home-manager configuration with hardware-specific settings
  home-manager = {
    extraSpecialArgs = {
      inherit inputs self;
      inherit hardwareConfig;
    };
    users.codyt = {
      home.stateVersion = "25.05";
      imports = [
        ../../users/cody/desktop.nix
        inputs.nixos-secrets.homeModules.default
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };
}
