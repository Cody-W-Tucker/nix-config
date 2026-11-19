{
  den.aspects.seerr.nixos =
    {
      mkNginxVhost,
      config,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Jellyseerr = {
        group = "Collect";
        order = 10;
        card = {
          icon = "jellyseerr";
          href = "https://request.${domain}";
          description = "Request Media Service";
        };
      };

      services.seerr.enable = true;

      services.nginx.virtualHosts = mkNginxVhost {
        host = "request.${domain}";
        port = config.services.seerr.port;
        proxyWebsockets = true;
      };

      nas.backups.sqlite = [
        {
          name = "seerr";
          source = "/var/lib/seerr/db/db.sqlite3";
        }
      ];
    };
}
