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
      codyos.homepage.cards.Sonarr = {
        group = "Manage";
        order = 10;
        card = {
          href = "https://sonarr.${domain}";
          icon = "sonarr";
          description = "Tv Show Search";
        };
      };

      codyos.homepage.cards.Radarr = {
        group = "Manage";
        order = 20;
        card = {
          href = "https://radarr.${domain}";
          icon = "radarr";
          description = "Movie Search";
        };
      };

      codyos.homepage.cards.Readarr = {
        group = "Manage";
        order = 30;
        card = {
          href = "https://readarr.${domain}";
          icon = "readarr";
          description = "Book Search";
        };
      };

      codyos.homepage.cards.Lidarr = {
        group = "Manage";
        order = 50;
        card = {
          href = "https://lidarr.${domain}";
          icon = "lidarr";
          description = "Music Search";
        };
      };

      codyos.homepage.cards.Bazarr = {
        group = "Manage";
        order = 60;
        card = {
          href = "https://bazarr.${domain}";
          icon = "bazarr";
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
