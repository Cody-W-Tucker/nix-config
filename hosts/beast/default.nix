{
  config,
  pkgs,
  ...
}:

let
  site = config.codyos.site;
in
{
  # Shared profiles and Home Manager wiring come from den/hosts/beast.nix.
  imports = [ ./hardware-configuration.nix ];

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

  # Kernel (hardware modules and quirks are in hardware-configuration.nix).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── Nix ─────────────────────────────────────────────────────
  # The NAS pre-builds this host nightly and serves it over Tailscale
  # (modules/nas/binary-cache). Its priority (30) puts it ahead of the public caches.
  nix.settings = {
    extra-substituters = [ "http://${site.hosts.nas.tailscale}:5000" ];
    extra-trusted-public-keys = [ "nas-cache-1:Uy5hdzmlVo4igOUVu0aZSZz6Y97QLF2ly2sJK21wLPg=" ];
    # Give up on an unreachable NAS quickly and use the next cache.
    connect-timeout = 5;
  };

  # ── Drives ──────────────────────────────────────────────────
  # Native units keep unavailable NAS shares out of fstab-generator during
  # systemd re-execution: https://github.com/systemd/systemd/issues/44396
  system.fsPackages = [
    pkgs.nfs-utils
    pkgs.cifs-utils
  ];
  systemd.mounts = [
    {
      what = "//${site.hosts.nas.lan}/PaperlessConsume";
      where = "/mnt/paperless-consume";
      type = "cifs";
      options = "guest,uid=${toString config.ids.uids.scanner},gid=${toString config.ids.gids.scanner}";
      mountConfig.TimeoutSec = "10s";
    }
    {
      what = "${site.hosts.nas.lan}:/mnt/projects";
      where = "${site.user.home}/Projects";
      type = "nfs";
      options = "noatime";
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
    }
    {
      what = "${site.hosts.nas.lan}:/mnt/knowledge";
      where = "${site.user.home}/Knowledge";
      type = "nfs";
      options = "noatime";
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
    }
  ];
  systemd.automounts = [
    {
      where = "/mnt/paperless-consume";
      wantedBy = [ "remote-fs.target" ];
      automountConfig.TimeoutIdleSec = "60s";
    }
    {
      where = "${site.user.home}/Projects";
      wantedBy = [ "remote-fs.target" ];
    }
    {
      where = "${site.user.home}/Knowledge";
      wantedBy = [ "remote-fs.target" ];
    }
  ];
  # Share folders (Documents, Music, …) are bind-mounted by syncthing.nix.
  # Networking
  networking = {
    hostName = "beast";
    networkmanager.settings.connection = {
      # MT7925 Bluetooth is more stable when NetworkManager does not power-save Wi-Fi.
      "wifi.powersave" = 2;
    };
    interfaces.eno1.wakeOnLan = {
      enable = true;
      policy = [ "magic" ];
    };
  };

  # Should be the same as the version of NixOS you installed on this machine.
  system.stateVersion = "25.05"; # Did you read the comment?
}
