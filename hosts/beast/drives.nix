{
  pkgs,
  ...
}:

let
  workBtrfsMembers = [
    "/dev/disk/by-partlabel/work-a"
    "/dev/disk/by-partlabel/work-b"
  ];
  workBtrfsMountOptions = map (device: "device=${device}") workBtrfsMembers ++ [
    "subvolid=5"
    "compress=zstd"
    "noatime"
    "discard=async"
  ];
in
{
  boot.extraModprobeConfig = ''
    options btusb enable_autosuspend=n reset=1
  '';

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
    "/mnt/work" = {
      device = "/dev/disk/by-uuid/34882b6b-6f50-4caa-93ff-b27688c41f1a";
      fsType = "btrfs";
      options = workBtrfsMountOptions;
    };
  };

  services.btrfs.autoScrub = {
    enable = true;
    interval = "*-*-01 09:00:00";
    fileSystems = [ "/mnt/work" ];
  };

  systemd = {
    tmpfiles.rules = [
      "d /mnt/work/dev 0755 codyt users - -"
      "d /mnt/work/dev/hermes 2770 hermes hermes - -"
      "d /mnt/work/vm 0755 codyt users - -"
      "d /mnt/work/cache 0755 codyt users - -"
      "d /mnt/work/media 0755 codyt users - -"
      "d /mnt/work/cache/ai 0755 codyt users - -"
    ];

    # Spread the monthly scrub over a window so it rarely collides with
    # suspend transitions (this host sleeps after 2 h of idle).
    timers."btrfs-scrub-mnt-work".timerConfig.RandomizedDelaySec = "3h";

    services."btrfs-scrub-mnt-work" = {
      after = [ "mnt-work.mount" ];
      requires = [ "mnt-work.mount" ];
    };

    services.work-btrfs-nocow = {
      description = "Apply NOCOW attribute to workspace heavy-write directories";
      wantedBy = [ "multi-user.target" ];
      after = [
        "mnt-work.mount"
      ];
      requires = [
        "mnt-work.mount"
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
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 6144; # 6GB swap file to avoid OOM killer on low-memory workloads
    }
  ];
}
