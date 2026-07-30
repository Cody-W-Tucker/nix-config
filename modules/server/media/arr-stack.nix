{
  mkMediaVhost,
  config,
  lib,
  ...
}:

let
  # Each entry maps a service to the NixOS option that holds its
  # configured listen port, so vhost proxyPass values stay in sync
  # with the service's own configuration rather than duplicating
  # literal port numbers.
  arrs = [
    {
      name = "sonarr";
      port = config.services.sonarr.settings.port;
    }
    {
      name = "radarr";
      port = config.services.radarr.settings.port;
    }
    {
      name = "readarr";
      port = config.services.readarr.settings.port;
    }
    {
      name = "bazarr";
      port = config.services.bazarr.settings.port;
    }
    {
      name = "lidarr";
      port = config.services.lidarr.settings.port;
    }
  ];
in
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
      lib.foldl'
        (
          acc: arr:
          acc
          // mkMediaVhost {
            host = "${arr.name}.homehub.tv";
            inherit (arr) port;
          }
        )
        (mkMediaVhost {
          host = "prowlarr.homehub.tv";
          port = config.services.prowlarr.settings.port;
        })
        arrs;
  };
}
