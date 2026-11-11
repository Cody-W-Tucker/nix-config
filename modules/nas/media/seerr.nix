{
  mkNginxVhost,
  config,
  ...
}:

let
  inherit (config.codyos.site) domain;
in
{
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
}
