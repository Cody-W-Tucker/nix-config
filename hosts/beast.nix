{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}:

# Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070 | RAM: 64GB | Storage: 2TB & 2 1TB Drives(unmapped) NVMe SSD

let
  hardwareConfig = {
    # Controls the monitor layout for hyprland
    workspace = [ "1, monitor:DP-1, default:true" ];
    monitor = [
      "DP-1,2560x1440@239.97,0x0,1,bitdepth,10,vrr,2"
    ];
    # Suspend after 2 hours of idle
    hypridle.suspendTimeout = 7200;
    # Use CUDA for whisper (faster than Vulkan on Nvidia)
    whispAcceleration = "cuda";
  };
in
{
  imports = [
    ../modules/system/base.nix
    ../modules/desktop
    ../modules/desktop/gaming
    ../modules/desktop/hardware/nvidia.nix
    ../modules/services/llama-swap
    ../modules/server/ai

    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  # Home-manager configuration with hardware-specific settings
  home-manager = {
    extraSpecialArgs = {
      inherit inputs self;
      inherit hardwareConfig;
    };
    users.codyt = {
      home.stateVersion = "25.05";
      imports = [
        ../users/cody/ui.nix
        ../secrets/home-secrets.nix
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
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
      options btusb enable_autosuspend=n
      options mt7925e disable_aspm=Y
    '';
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
  };

  # Ensure 14th Gen Intel CPU works correctly
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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
    "/mnt/server-books" = {
      device = "192.168.1.31:/mnt/media/Media/Books";
      fsType = "nfs";
      options = [
        "x-systemd.automount"
        "noauto"
        "nfsvers=4.2"
      ];
    };

    # Multi-device Btrfs workspace pool spanning the two secondary NVMe drives.
    "/mnt/work" = {
      device = "/dev/disk/by-uuid/34882b6b-6f50-4caa-93ff-b27688c41f1a";
      fsType = "btrfs";
      options = [
        "subvolid=5"
        "compress=zstd"
        "noatime"
        "discard=async"
        "nofail"
      ];
    };
    "/mnt/work/dev" = {
      device = "/dev/disk/by-uuid/34882b6b-6f50-4caa-93ff-b27688c41f1a";
      fsType = "btrfs";
      options = [
        "subvol=dev"
        "compress=zstd"
        "noatime"
        "discard=async"
        "nofail"
      ];
    };
    "/mnt/work/vm" = {
      device = "/dev/disk/by-uuid/34882b6b-6f50-4caa-93ff-b27688c41f1a";
      fsType = "btrfs";
      options = [
        "subvol=vm"
        "compress=zstd"
        "noatime"
        "discard=async"
        "nofail"
      ];
    };
    "/mnt/work/cache" = {
      device = "/dev/disk/by-uuid/34882b6b-6f50-4caa-93ff-b27688c41f1a";
      fsType = "btrfs";
      options = [
        "subvol=cache"
        "compress=zstd"
        "noatime"
        "discard=async"
        "nofail"
      ];
    };
    "/mnt/work/media" = {
      device = "/dev/disk/by-uuid/34882b6b-6f50-4caa-93ff-b27688c41f1a";
      fsType = "btrfs";
      options = [
        "subvol=media"
        "compress=zstd"
        "noatime"
        "discard=async"
        "nofail"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/work/dev 0755 codyt users - -"
    "d /mnt/work/vm 0755 codyt users - -"
    "d /mnt/work/cache 0755 codyt users - -"
    "d /mnt/work/media 0755 codyt users - -"
  ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/mnt/work" ];
  };

  systemd.services.work-btrfs-nocow = {
    description = "Apply NOCOW attribute to workspace heavy-write directories";
    wantedBy = [ "multi-user.target" ];
    after = [
      "mnt-work-vm.mount"
      "mnt-work-cache.mount"
    ];
    requires = [
      "mnt-work-vm.mount"
      "mnt-work-cache.mount"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "work-btrfs-nocow" ''
        set -eu

        # Apply NOCOW to empty directories so future VM images and caches avoid CoW overhead.
        ${pkgs.e2fsprogs}/bin/chattr +C /mnt/work/vm
        ${pkgs.e2fsprogs}/bin/chattr +C /mnt/work/cache
      '';
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 65536; # 64GB swap file to handle memory-intensive builds
    }
  ];

  services.llama-swap = {
    enable = true;
    acceleration = "cuda";
    port = 8081;
    modelOwner = "codyt";
    modelGroup = "users";
    enabledModels = [
      "qwen3.5-0.8b"
      "qwen3.5-4b"
      "qwen3.5-9b"
    ];
    modelOverrides = {
      # Short TTL for larger models - only used programmatically, free VRAM quickly
      "qwen3.5-4b" = {
        ttl = 10;
      };
      "qwen3.5-9b" = {
        ttl = 10;
      };
      "qwen3.5-0.8b" = {
        extraArgs = [
          "--parallel"
          "4"
        ];
      };
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
}
