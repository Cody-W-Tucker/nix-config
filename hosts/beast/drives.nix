{ config, pkgs, ... }:

{
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

    # NFS mounts from NAS (192.168.1.108)
    "/home/codyt/Projects" = {
      device = "192.168.1.108:/mnt/projects";
      fsType = "nfs";
      options = [
        "noatime"
        "nofail"
        "x-systemd.automount"
        "x-systemd.requires=network-online.target"
      ];
    };
    "/home/codyt/Knowledge" = {
      device = "192.168.1.108:/mnt/knowledge";
      fsType = "nfs";
      options = [
        "noatime"
        "nofail"
        "x-systemd.automount"
        "x-systemd.requires=network-online.target"
      ];
    };

  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 6144; # 6GB swap file to avoid OOM killer on low-memory workloads
    }
  ];
}
