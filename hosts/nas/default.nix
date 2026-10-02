{
  config,
  inputs,
  pkgs,
  self,
  ...
}:

{
  imports = [
    ../../modules/system/base.nix
    ../../modules/hardware/baseline.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/nas
    ../../modules/services/opencode
    inputs.workflow.nixosModules.default
    ./models.nix
    # VPN for media
    inputs.vpn-confinement.nixosModules.default
  ];

  # Bootloader.
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
    kernelParams = [ "zfs.zfs_arc_max=8589934592" ]; # 8 GiB
    supportedFilesystems = [ "zfs" ];
    zfs.extraPools = [ "backup" ];
    zfs.forceImportRoot = false;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
    };
    "home" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/CBDD-BD07";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
    "/mnt/media" = {
      device = "/dev/disk/by-uuid/27ddc2ef-8f21-401d-b9eb-3ed4541c16c9";
      fsType = "ext4";
      options = [
        "defaults"
        "noatime"
        "nofail"
        "x-systemd.device-timeout=30s"
        "errors=remount-ro"
      ];
    };
    "/mnt/appdata" = {
      device = "/dev/disk/by-uuid/17888441-14c2-465f-9786-b2eae0220553";
      fsType = "btrfs";
      options = [
        "subvol=@appdata"
        "compress=zstd"
        "noatime"
      ];
    };
    "/mnt/tmp" = {
      device = "/dev/disk/by-uuid/17888441-14c2-465f-9786-b2eae0220553";
      fsType = "btrfs";
      options = [
        "subvol=@tmp"
        "compress=zstd"
        "noatime"
      ];
    };
    "/mnt/projects" = {
      device = "/dev/disk/by-uuid/17888441-14c2-465f-9786-b2eae0220553";
      fsType = "btrfs";
      options = [
        "subvol=@projects"
        "compress=zstd"
        "noatime"
      ];
    };
    "/mnt/knowledge" = {
      device = "/dev/disk/by-uuid/17888441-14c2-465f-9786-b2eae0220553";
      fsType = "btrfs";
      options = [
        "subvol=@knowledge"
        "compress=zstd"
        "noatime"
      ];
    };
  };

  # ── User bind mounts ─────────────────────────────────────────
  # Bind NAS-local storage into codyt's home directory:
  # Projects and Knowledge from independent Btrfs subvolumes,
  # declared directly via fileSystems above.

  fileSystems."/home/codyt/Projects" = {
    device = "/mnt/projects";
    fsType = "none";
    options = [ "bind" ];
  };

  fileSystems."/home/codyt/Knowledge" = {
    device = "/mnt/knowledge";
    fsType = "none";
    options = [ "bind" ];
  };

  # Syncthing-safe individual mappings for media dirs (Beast-style).
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

  services = {
    # Auto configure usb etc, when plugedin
    udisks2.enable = true;
    tailscale = {
      enable = true;
      # Enable IP forwarding so this host can act as a subnet router for the LAN.
      useRoutingFeatures = "server";
      extraSetFlags = [
        "--advertise-routes=192.168.1.0/24"
        "--accept-dns=false"
      ];
    };
    zfs.autoScrub.enable = true;
    zfs.autoSnapshot = {
      enable = true;
      frequent = 0;
      hourly = 0;
      daily = 7;
      weekly = 4;
      monthly = 3;
      flags = "-k -p --utc";
    };
    wake-beast.enable = false;
    opencode.enable = true; # web server for opencode
    nvidia-power-limit = {
      enable = true;
      watts = 123;
    };
  };

  # Networking
  networking = {
    hostName = "nas";
    hostId = "60f0861b";
    networkmanager.enable = true;
    # Static LAN address for the NAS so it keeps a predictable IP across router
    # resets. Starlink does not publish a reserved DHCP pool, so we pin the
    # active physical connection instead of relying on a lease.
    useDHCP = false;
    networkmanager.ensureProfiles.profiles."Wired connection 1" = {
      connection = {
        id = "Wired connection 1";
        uuid = "faa5cfb6-2e8f-34f2-981e-194fbc74a105";
        type = "802-3-ethernet";
        interface-name = "enp6s0";
        autoconnect = true;
        autoconnect-priority = 100;
      };
      ipv4 = {
        method = "manual";
        addresses = "192.168.1.2/24";
        gateway = "192.168.1.1";
        may-fail = false;
      };
      ipv6 = {
        # Leave IPv6 dynamic (SLAAC/RA) as before; only IPv4 is pinned static.
        method = "auto";
      };
    };
    firewall = {
      interfaces.tailscale0.allowedTCPPorts = [
        # Hermes API — reachable only over Tailscale (Beast→NAS voice pipeline)
        # Hermes Dashboard — remote web UI, authenticated via basic auth
        8642
        9119
      ];
      allowedTCPPorts = [
        # Syncthing GUI — shared module binds 0.0.0.0:8384; open firewall for LAN access
        8384
      ];
    };
  };

  # Docker package
  virtualisation.docker.package = pkgs.docker_29;

  hardware = {
    # NVIDIA GPU (RTX 5060)
    # NVIDIA driver is provided by hardware.nvidia settings, not xserver.videoDrivers
    graphics.enable = true;
    # NVIDIA container toolkit for CUDA container access
    nvidia-container-toolkit = {
      enable = true;
      suppressNvidiaDriverAssertion = true;
    };
    bluetooth = {
      # Bluetooth support for Home Assistant (prepares for future controller)
      enable = true;
      powerOnBoot = true;
    };
  };

  # Home-manager configuration
  home-manager = {
    extraSpecialArgs = {
      inherit inputs self;
    };
    users.codyt = {
      home.stateVersion = "25.11";
      imports = [
        ../../users/cody/server.nix
        ../../modules/services/hermes-agent
        inputs.nixos-secrets.homeModules.default
        inputs.nixvim-stable.homeModules.nixvim
      ];
    };
  };

  # Hermes runs as a Home Manager user service, so its backup wiring lives at
  # the NixOS level here: the state and CRM SQLite files are consistently
  # exported by Restic's pre-backup step, while remaining Hermes state is a
  # direct Restic input (live *.db* files stay excluded centrally).
  nas.backups.sqlite = [
    {
      name = "hermes";
      source = "/home/codyt/.local/share/hermes/state.db";
      filename = "state.db";
    }
    {
      name = "hermes";
      source = "/home/codyt/.local/share/hermes/crm/crm.db";
      filename = "crm.db";
    }
  ];
  nas.backups.dataDirectories = [
    "/home/codyt/.local/share/hermes"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}
