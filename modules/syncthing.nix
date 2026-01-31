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
    guiAddress = "0.0.0.0:8384";
    # Shared Syncthing device definitions
    settings.devices = {
      "server" = {
        id = "KBLKS5F-5MMRUM6-M2LZHPW-CQMDXM4-RPHV7WT-V7Y6PQZ-QK3WUC2-MFRB7AC";
      };
      "Cody's Pixel" = {
        id = "T3CJ4YF-RDXUROW-E7NZOKN-BZXE67E-NQWOHVO-UD5BCCS-2A6KONP-LTA5BQF";
      };
      "beast" = {
        id = "WS3XKRH-JILABRE-NLK2NU6-BGPXTOY-TOO2K75-UYEY7HB-KO7NKAC-I37UGQ3";
      };
      "aiserver" = {
        id = "2HCQD2S-RHNRARF-CR7XUXC-J76FL3E-DIA7TGH-OC7VVGF-BADHGJY-ZFWNCQY";
      };
    };
  };

  # Ensure syncthing directories exist with proper permissions
  systemd.tmpfiles.rules = [
    "d /mnt 0755 root root - -"
    "d /mnt/backup 0755 codyt users - -"
    "d /mnt/backup/Share 0755 codyt users - -"
    "d /mnt/backup/Obsidian 0755 codyt users - -"
  ];

  # Hostname-specific folder configurations
  services.syncthing.settings.folders = lib.mkMerge [
    # Server folders
    (lib.mkIf (config.networking.hostName == "server") {
      "share" = {
        path = "/mnt/media/Share";
        devices = [
          "server"
          "beast"
          "aiserver"
        ];
      };
    })

    # Beast folders
    (lib.mkIf (config.networking.hostName == "beast") {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [
          "aiserver"
          "beast"
          "server"
        ];
      };
      "Cody's Obsidian" = {
        path = "/mnt/backup/Obsidian";
        devices = [
          "Cody's Pixel"
          "beast"
          "aiserver"
        ];
      };
    })

    # Aiserver folders
    (lib.mkIf (config.networking.hostName == "aiserver") {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [
          "server"
          "beast"
          "aiserver"
        ];
      };
      "Cody's Obsidian" = {
        path = "/mnt/backup/Obsidian";
        devices = [
          "Cody's Pixel"
          "beast"
          "aiserver"
        ];
      };
    })
  ];
}
