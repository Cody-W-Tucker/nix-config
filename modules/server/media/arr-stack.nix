{
  mkMediaVhost,
  ...
}:

{
  services = {
    sonarr = {
      enable = true;
      group = "media";
    };
    radarr = {
      enable = true;
      group = "media";
    };
    readarr = {
      enable = true;
      group = "media";
    };
    bazarr = {
      enable = true;
      group = "media";
    };
    lidarr = {
      enable = true;
      group = "media";
    };
    # Indexer Manager (no group override — matches original)
    prowlarr.enable = true;

    nginx.virtualHosts =
      mkMediaVhost { service = "sonarr"; }
      // mkMediaVhost { service = "radarr"; }
      // mkMediaVhost { service = "readarr"; }
      // mkMediaVhost { service = "bazarr"; }
      // mkMediaVhost { service = "lidarr"; }
      // mkMediaVhost { service = "prowlarr"; };
  };
}
