{ config, lib, ... }:

{
  # Shared Syncthing device definitions
  services.syncthing.settings.devices = {
    "server" = {
      id = "RWUUJ5C-MDAHVZZ-M7FK6NB-W5WAWIX-QFFDD4G-7QAQWHG-73ZM7Y5-6X5YCQR";
    };
    "workstation" = {
      id = "7YDHDRD-FYM5KFG-BKQLPGL-RFP6JFE-DXD27F4-HVJWV3A-TAKVJSX-LGNHNQM";
    };
    "Cody's Pixel" = {
      id = "T3CJ4YF-RDXUROW-E7NZOKN-BZXE67E-NQWOHVO-UD5BCCS-2A6KONP-LTA5BQF";
    };
    "beast" = {
      id = "WS3XKRH-JILABRE-NLK2NU6-BGPXTOY-TOO2K75-UYEY7HB-KO7NKAC-I37UGQ3";
    };
    "aiserver" = {
      id = "XZHQW3I-WDGDIXT-2NRBVX4-KYHS324-UNSWTZP-LUQKWYE-VPILMKA-2H6MFAA";
    };
  };

  # Basic Syncthing service configuration
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    overrideDevices = true;
    overrideFolders = true;
    guiAddress = "0.0.0.0:8384";
  };

  # Hostname-specific folder configurations
  services.syncthing.settings.folders = lib.mkMerge [
    # Server folders
    (lib.mkIf (config.networking.hostName == "server") {
      "share" = {
        path = "/mnt/media/Share";
        devices = [
          "server"
          "workstation"
          "beast"
        ];
      };
    })

    # Workstation folders
    (lib.mkIf (config.networking.hostName == "workstation") {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [
          "server"
          "workstation"
        ];
      };
      "Cody's Obsidian" = {
        path = "/mnt/backup/Obsidian";
        devices = [
          "workstation"
          "Cody's Pixel"
        ];
      };
    })

    # Beast folders
    (lib.mkIf (config.networking.hostName == "beast") {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [
          "server"
          "aiserver"
        ];
      };
      "Cody's Obsidian" = {
        path = "/mnt/backup/Obsidian";
        devices = [ "Cody's Pixel" ];
      };
    })

    # Aiserver folders
    (lib.mkIf (config.networking.hostName == "aiserver") {
      "share" = {
        path = "/mnt/backup/Share";
        devices = [
          "server"
          "beast"
        ];
      };
      "Cody's Obsidian" = {
        path = "/mnt/backup/Obsidian";
        devices = [ "Cody's Pixel" ];
      };
    })
  ];
}
