{
  config,
  mkNginxVhost,
  ...
}:

let
  inherit (config.codyos.site) domain;
in
{
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
}
