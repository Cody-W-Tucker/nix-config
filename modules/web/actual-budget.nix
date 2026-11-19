{
  den.aspects.actual-budget.nixos =
    {
      config,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.ActualBudget = {
        group = "Tools";
        order = 50;
        card = {
          href = "https://budget.${domain}";
          icon = "https://budget.${domain}/favicon.ico";
          description = "Personal Budget";
        };
      };

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
    };
}
