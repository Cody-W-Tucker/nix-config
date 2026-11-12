{
  config,
  mkNginxVhost,
  ...
}:

let
  inherit (config.codyos.site) domain;
in
{
  services.nginx.virtualHosts = mkNginxVhost {
    host = "budget.${domain}";
    port = config.services.actual.settings.port;
    proxyWebsockets = true;
  };

  services.actual = {
    enable = true;
    settings.port = 5006;
    settings.hostname = "127.0.0.1";
  };

  nas.backups.sqlite = [
    {
      name = "actual";
      source = "/var/lib/actual/server-files/account.sqlite";
    }
  ];
}
