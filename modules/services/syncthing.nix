{ config, lib, ... }:

{

  # Basic Syncthing service configuration
  services.syncthing = {
    enable = true;
    user = "codyt";
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

  # Ensure syncthing directories exist with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt 0755 root root - -"
    "d /mnt/backup 0755 codyt users - -"
    "d /mnt/backup/Share 0755 codyt users - -"
  ];

  # Hostname-specific folder configurations
  services.syncthing.settings.folders = lib.mkMerge [
    # Beast folders
    (lib.mkIf (config.networking.hostName == "beast") {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [
          "beast"
          "nas"
        ];
      };
    })

    # NAS folders
    (lib.mkIf (config.networking.hostName == "nas") {
      "Share" = {
        path = "/mnt/backup/Share";
        devices = [
          "nas"
          "beast"
        ];
      };
    })
  ];
}
