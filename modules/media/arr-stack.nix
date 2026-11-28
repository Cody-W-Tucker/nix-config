{
  den.aspects.arr-stack.nixos =
    {
      config,
      lib,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
      confinedServices = [
        "prowlarr"
        "sonarr"
        "radarr"
        "readarr"
        "bazarr"
        "lidarr"
      ];
      mediaServices = lib.remove "prowlarr" confinedServices;
      namespaceAddress = "192.168.15.1";
      mkConfinedVhost =
        name:
        mkNginxVhost (
          (
            if name == "bazarr" then
              {
                host = "bazarr.${domain}";
                port = config.services.bazarr.listenPort;
              }
            else
              { service = name; }
          )
          // {
            proxyHost = namespaceAddress;
          }
        );
    in
    {
      codyos.homepage.cards =
        lib.mapAttrs
          (name: card: {
            group = "Manage";
            inherit (card) order;
            card = {
              href = "https://${lib.toLower name}.${domain}";
              icon = lib.toLower name;
              inherit (card) description;
            };
          })
          {
            Sonarr = {
              order = 10;
              description = "Tv Show Search";
            };
            Radarr = {
              order = 20;
              description = "Movie Search";
            };
            Readarr = {
              order = 30;
              description = "Book Search";
            };
            Lidarr = {
              order = 50;
              description = "Music Search";
            };
            Bazarr = {
              order = 60;
              description = "Subtitle Search";
            };
          };

      systemd.services = lib.genAttrs confinedServices (_: {
        vpnConfinement = {
          enable = true;
          vpnNamespace = "wg";
        };
      });

      networking.firewall.interfaces.wg-br.allowedTCPPorts = [
        config.services.flaresolverr.port
      ];

      services =
        lib.genAttrs mediaServices (_: {
          enable = true;
          group = "media";
        })
        // {
          prowlarr.enable = true;
          flaresolverr.enable = true;

          nginx.virtualHosts = lib.mergeAttrsList (map mkConfinedVhost confinedServices);
        };

      nas.backups.sqlite = [
        {
          name = "radarr";
          source = "/var/lib/radarr/.config/Radarr/radarr.db";
        }
        {
          name = "sonarr";
          source = "/var/lib/sonarr/.config/NzbDrone/sonarr.db";
        }
        {
          name = "lidarr";
          source = "/var/lib/lidarr/.config/Lidarr/lidarr.db";
        }
        {
          name = "readarr";
          source = "/var/lib/readarr/readarr.db";
        }
        {
          name = "bazarr";
          source = "/var/lib/bazarr/db/bazarr.db";
        }
        {
          name = "prowlarr";
          source = "/var/lib/prowlarr/prowlarr.db";
        }
      ];
    };
}
