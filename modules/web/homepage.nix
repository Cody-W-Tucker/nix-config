{ den, ... }:
let
  groups = [
    "Business"
    "Tools"
    "Consume"
    "Collect"
    "Manage"
    "Network"
  ];
in
{
  den.default.includes = [ den.aspects.homepage.cards ];

  den.aspects = {
    nas.includes = [ den.aspects.homepage ];
    homepage.cards.nixos =
      { lib, ... }:
      let
        inherit (lib) mkOption types;
      in
      {
        options.codyos.homepage.cards = mkOption {
          default = { };
          description = "Dashboard cards contributed by included service aspects.";
          type = types.attrsOf (
            types.submodule {
              options = {
                group = mkOption { type = types.enum groups; };
                order = mkOption {
                  type = types.int;
                  default = 100;
                };
                card = mkOption { type = types.attrsOf types.str; };
              };
            }
          );
        };
      };

    homepage.nixos =
      {
        config,
        lib,
        mkNginxVhost,
        ...
      }:

      let
        inherit (config.codyos.site) domain;
        cards = config.codyos.homepage.cards;
        names = builtins.attrNames cards;
        byOrder = a: b: cards.${a}.order < cards.${b}.order;
        sections = lib.concatMap (
          group:
          let
            members = lib.sort byOrder (builtins.filter (name: cards.${name}.group == group) names);
          in
          lib.optional (members != [ ]) { ${group} = map (name: { ${name} = cards.${name}.card; }) members; }
        ) groups;
      in
      {
        services = {
          nginx.virtualHosts = mkNginxVhost {
            host = domain;
            port = config.services.homepage-dashboard.listenPort;
            proxyWebsockets = true;
          };

          homepage-dashboard = {
            enable = true;
            allowedHosts = domain;
            settings = {
              title = "HomeHub.tv";
              cardBlur = "sm";
              layout = {
                Business = {
                  style = "row";
                  columns = 3;
                };
                Tools = {
                  style = "row";
                  columns = 3;
                };
              };
              headerStyle = "boxedWidgets";
              target = "_self";
              quicklaunch = {
                searchDescription = true;
                hideInternetSearch = true;
                showSearchSuggestions = true;
                hideVisitURL = true;
              };
            };
            widgets = [
              {
                resources = {
                  label = "System";
                  cpu = true;
                  memory = true;
                  disk = "/";
                  cputemp = true;
                  tempmin = 30;
                  tempmax = 95;
                  refresh = 3000;
                  uptime = true;
                };
              }
              {
                resources = {
                  label = "Media";
                  disk = "/mnt/media";
                };
              }
              {
                resources = {
                  label = "Backup";
                  disk = "/mnt/backup";
                };
              }
              {
                openmeteo = {
                  label = "Kearney";
                  latitude = 40.699670;
                  longitude = -99.010310;
                  timezone = "America/Chicago";
                  units = "imperial";
                  cache = 5;
                  format.maximumFractionDigits = 0;
                };
              }
            ];
            services = sections;
          };
        };
      };
  };
}
