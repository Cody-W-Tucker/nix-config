{
  config,
  lib,
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
    ../../modules/services/hermes-agent
    ../../modules/services/opencode
    ./models.nix
    # VPN for media
    inputs.vpn-confinement.nixosModules.default
    # Keep track of these fixes and remove them when the upstream issues are resolved.
    ../fixes.nix
  ];

  services.opencode.enable = true;

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
    # Cap ZFS ARC at 32 GiB (half of 64 GB DDR5-6000 physical RAM)
    kernelParams = [ "zfs.zfs_arc_max=34359738368" ];
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
  };

  # ── User bind mounts (after ZFS datasets) ────────────────────
  # Make NAS-local ZFS datasets available under codyt's home directory.
  # Ordering ensures the ZFS oneshot services create the source mountpoints first.

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

  # Bind mounts must wait for the ZFS dataset services to create their source paths.
  systemd.mounts = [
    {
      what = "/mnt/projects";
      where = "/home/codyt/Projects";
      type = "none";
      options = "bind";
      wantedBy = [ "local-fs.target" ];
      after = [ "zfs-create-backup-projects.service" ];
      requires = [ "zfs-create-backup-projects.service" ];
    }
    {
      what = "/mnt/knowledge";
      where = "/home/codyt/Knowledge";
      type = "none";
      options = "bind";
      wantedBy = [ "local-fs.target" ];
      after = [ "zfs-create-backup-knowledge.service" ];
      requires = [ "zfs-create-backup-knowledge.service" ];
    }
  ];

  # Auto configure usb etc, when plugedin
  services.udisks2.enable = true;
  services.tailscale = {
    enable = true;
    # Enable IP forwarding so this host can act as a subnet router for the LAN.
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-routes=192.168.1.0/24" ];
  };
  services.zfs.autoScrub.enable = true;
  services.wake-beast.enable = true;

  # Bluetooth support for Home Assistant (prepares for future controller)
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Syncthing GUI — shared module binds 0.0.0.0:8384; open firewall for LAN access
  networking.firewall.allowedTCPPorts = [
    8384
  ];

  # Hermes API — reachable only over Tailscale (Beast→NAS voice pipeline)
  # Hermes Dashboard — remote web UI, authenticated via basic auth
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    8642
    9119
  ];

  # Docker package
  virtualisation.docker.package = pkgs.docker_29;

  # Networking
  networking = {
    hostName = "nas";
    hostId = "60f0861b";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  # NVIDIA GPU (RTX 5060) — headless CUDA infrastructure for Hermes
  hardware.graphics.enable = true;
  # NVIDIA driver is provided by hardware.nvidia settings, not xserver.videoDrivers
  hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = true;

  # Home-manager configuration
  home-manager = {
    extraSpecialArgs = {
      inherit inputs self;
    };
    users.codyt = {
      home.stateVersion = "25.11";
      imports = [
        ../../users/cody/server.nix
        inputs.nixos-secrets.homeModules.default
        inputs.nixvim-stable.homeModules.nixvim
      ];
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
