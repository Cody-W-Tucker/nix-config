{
  config,
  inputs,
  pkgs,
  self,
  ...
}:

let
  site = config.codyos.site;
  hardwareConfig = {
    # Controls the monitor layout for hyprland
    workspace = [
      {
        workspace = "1";
        monitor = "DP-1";
        default = true;
      }
    ];
    monitor = [
      # Samsung Odyssey G65B: HDR output with SDR brightness tuned for the desktop.
      {
        output = "DP-1";
        mode = "2560x1440@239.97";
        position = "0x0";
        vrr = 3;
        bitdepth = 10;
        cm = "hdr";
        sdrbrightness = 1;
        sdrsaturation = 1;
        sdr_max_luminance = 340;
      }
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

    # Using community hardware configurations
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

  # ── Machine ─────────────────────────────────────────────────
  # Main home desktop workstation: CPU: i9-14900kf | GPU: Nvidia 3070 | Storage: 2TB NVMe

  # ── Features ────────────────────────────────────────────────
  codyos = {
    docker.enable = true;
    gaming.enable = true;
    hardware.nvidia.enable = true;
    hardware.openrazer.enable = true;
    paperless-scanning.enable = true;
  };

  # Bootloader.
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
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
    "/mnt/paperless-consume" = {
      device = "//${site.hosts.nas.lan}/PaperlessConsume";
      fsType = "cifs";
      options = [
        "guest"
        "uid=${toString config.ids.uids.scanner}"
        "gid=${toString config.ids.gids.scanner}"
        "nofail"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=10s"
      ];
    };
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
    # Share folders (Documents, Music, …) are bind-mounted by syncthing.nix.

    # NFS mounts from NAS
    "${site.user.home}/Projects" = {
      device = "${site.hosts.nas.lan}:/mnt/projects";
      fsType = "nfs";
      options = [
        "noatime"
        "nofail"
        "x-systemd.automount"
        "x-systemd.requires=network-online.target"
      ];
    };
    "${site.user.home}/Knowledge" = {
      device = "${site.hosts.nas.lan}:/mnt/knowledge";
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
    users.${site.user.name} = {
      home.stateVersion = "25.05";
      imports = [
        ../../users/cody/desktop.nix
        inputs.nixos-secrets.homeModules.default
        inputs.nixvim.homeModules.nixvim
      ];
    };
  };
}
