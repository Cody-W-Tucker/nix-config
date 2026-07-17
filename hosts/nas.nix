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
    ../modules/system/base.nix
    ../modules/desktop/hardware/nvidia.nix
    ../modules/server
    # VPN for media
    inputs.vpn-confinement.nixosModules.default
  ];

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
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
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

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

  swapDevices = [ ];

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
  services.tailscale.enable = true;
  services.zfs.autoScrub.enable = true;
  services.wake-beast.enable = true;

  # Syncthing GUI — shared module binds 0.0.0.0:8384; open firewall for LAN access
  networking.firewall.allowedTCPPorts = [ 8384 ];

  # Docker package
  virtualisation.docker.package = pkgs.docker_29;

  # Networking
  networking = {
    hostName = "nas";
    hostId = "60f0861b";
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;
  };

  # NVIDIA GPU (GTX 1650) — shared module provides kernel driver, CUDA, GPU exporter, power mgmt
  # Headless: no display manager or desktop session, so X11 nvidia driver is installed but idle.
  # DO NOT force-empty videoDrivers — hardware.nvidia module requires "nvidia" in the list
  # to activate kernel modules, firmware, and nvidia-smi.
  # Enable the /run/opengl-driver symlink farm so non-X services (Jellyfin ffmpeg) can find
  # libcuda.so.1, libnvcuvid.so, etc. without a running display server.
  hardware.graphics.enable = true;

  # Home-manager configuration
  home-manager = {
    extraSpecialArgs = {
      inherit inputs self;
    };
    users.codyt = {
      home.stateVersion = "25.11";
      imports = [
        ../users/cody/server.nix
        inputs.nixos-secrets.homeModules.default
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
