{ mkMediaVhost, lib, ... }:

let
  arrs = [
    {
      name = "sonarr";
      port = 8989;
    }
    {
      name = "radarr";
      port = 7878;
    }
    {
      name = "readarr";
      port = 8787;
    }
    {
      name = "bazarr";
      port = 6767;
    }
    {
      name = "lidarr";
      port = 8686;
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
            port = arr.port;
            recommendedProxySettings = true;
          }
        )
        (mkMediaVhost {
          host = "prowlarr.homehub.tv";
          port = 9696;
          recommendedProxySettings = true;
        })
        arrs;
  };
}
