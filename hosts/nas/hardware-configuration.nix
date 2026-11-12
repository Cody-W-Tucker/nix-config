# NAS hardware: disks, filesystems, and initrd/kernel modules. Storage policy
# (ZFS pools, ARC size) and host policy live in default.nix; ZFS snapshot
# policy lives in modules/nas/backups.nix.
{
  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
      options = [ "noatime" ];
    };
    "/home" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
      options = [
        "subvol=home"
        "noatime"
      ];
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/0e0786ed-3740-4a19-83af-cf356e55393b";
      fsType = "btrfs";
      options = [
        "subvol=nix"
        "noatime"
      ];
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
}
