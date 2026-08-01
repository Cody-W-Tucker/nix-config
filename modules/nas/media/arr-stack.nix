{
  config,
  mkNginxVhost,
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
      mkNginxVhost { service = "sonarr"; }
      // mkNginxVhost { service = "radarr"; }
      // mkNginxVhost { service = "readarr"; }
      // mkNginxVhost {
        host = "bazarr.homehub.tv";
        port = config.services.bazarr.listenPort;
      }
      // mkNginxVhost { service = "lidarr"; }
      // mkNginxVhost { service = "prowlarr"; };
  };
}
