{ config, lib, ... }:

let
  inherit (config.codyos.site) user;
  share = "/mnt/backup/Share";
  # Share subfolders bind-mounted into the user's home on every host.
  homeFolders = [
    "Documents"
    "Music"
    "Pictures"
    "Videos"
  ];
in
{

  # Basic Syncthing service configuration
  services.syncthing = {
    enable = true;
    user = user.name;
    dataDir = "/var/lib/syncthing";
    openDefaultPorts = true;
    overrideDevices = true;
    overrideFolders = true;
    guiAddress = lib.mkDefault "0.0.0.0:8384";
    # Shared Syncthing device definitions
    settings.devices = {
      "beast" = {
        id = "WS3XKRH-JILABRE-NLK2NU6-BGPXTOY-TOO2K75-UYEY7HB-KO7NKAC-I37UGQ3";
      };
      "nas" = {
        id = "STU55DV-U3QK2RL-7UE5IGR-PRHOSQU-4SK4JUW-Y5YJP5R-IQLNAH2-QXAQBQQ";
      };
    };
  };

  # Sync and discovery ports are opened by openDefaultPorts. The web GUI is
  # reachable over Tailscale only: the NAS nginx proxies beast-syncthing.${domain}
  # to Beast's Tailscale address, and nas-syncthing.${domain} to the NAS locally.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8384 ];

  # Ensure syncthing directories exist with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt 0755 root root - -"
    "d /mnt/backup 0755 ${user.name} users - -"
    "d ${share} 0755 ${user.name} users - -"
  ];

  # Map Share subfolders into the home directory one by one, so the rest of
  # the home directory stays outside Syncthing.
  fileSystems = lib.genAttrs' homeFolders (
    name:
    lib.nameValuePair "${user.home}/${name}" {
      device = "${share}/${name}";
      fsType = "none";
      options = [
        "bind"
        "nofail"
      ]
      # Where /mnt/backup is a ZFS pool (NAS), its datasets are mounted by
      # zfs-mount.service rather than .mount units, so order after it.
      ++ lib.optionals config.boot.zfs.enabled [
        "x-systemd.requires=zfs-mount.service"
        "x-systemd.after=zfs-mount.service"
      ];
    }
  );

  # Shared folder, identical on every host that imports this module.
  services.syncthing.settings.folders."Share" = {
    path = share;
    devices = [
      "beast"
      "nas"
    ];
    ignorePatterns = [
      "node_modules"
      "npm"
      "pnpm"
      ".pnpm-store"
      ".git"
      ".venv/"
      ".bundle/"
      ".next/"
      "tmp/"
      "__pycache__/"
      ".turbo/"
      ".trash/"
    ];
  };
}
