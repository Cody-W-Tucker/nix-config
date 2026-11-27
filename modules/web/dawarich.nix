{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.dawarich ];

  den.aspects.dawarich.nixos =
    {
      config,
      pkgs,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Dawarich = {
        group = "Collect";
        order = 30;
        card = {
          href = "https://tracker.${domain}";
          icon = "dawarich";
          description = "Location Tracking";
        };
      };

      sops.secrets."dawarich-secret-key-base" = { };

      services.dawarich = {
        enable = true;
        webPort = 3004;
        localDomain = "tracker.${domain}";
        configureNginx = false;
        secretKeyBaseFile = config.sops.secrets."dawarich-secret-key-base".path;
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "tracker.${domain}";
        locations = {
          "/" = {
            root = "${pkgs.dawarich}/public";
            tryFiles = "$uri @dawarich";
          };
          "@dawarich" = {
            proxyPass = "http://127.0.0.1:3004";
            proxyWebsockets = true;
          };
        };
      };
    };
}
