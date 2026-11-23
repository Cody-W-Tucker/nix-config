{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.uptime-kuma ];

  den.aspects.uptime-kuma.nixos =
    {
      config,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.UptimeKuma = {
        group = "Tools";
        order = 70;
        card = {
          href = "https://uptime.${domain}";
          icon = "uptime-kuma";
          description = "Uptime Monitoring";
        };
      };

      services.uptime-kuma = {
        enable = true;
        settings = {
          UPTIME_KUMA_HOST = "127.0.0.1";
          UPTIME_KUMA_PORT = "3002";
        };
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "uptime.${domain}";
        port = config.services.uptime-kuma.settings.UPTIME_KUMA_PORT;
        proxyWebsockets = true;
      };

      nas.backups.sqlite = [
        {
          name = "uptime-kuma";
          source = "/var/lib/uptime-kuma/kuma.db";
        }
      ];
    };
}
