let

  domain = "homehub.tv";

in
{

  services = {
    nginx.virtualHosts."dashboard.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:8082";
    };

    homepage-dashboard = {

      # These options were already present in my configuration.

      enable = true;
      listenPort = 8082;

      # https://gethomepage.dev/latest/configs/settings/

      settings = {
        title = "HomeHub.tv";
      };

      # https://gethomepage.dev/latest/configs/services/

      services = [
        {
          Business = [
            {
              Nextcloud = {
                href = "https://cloud.${domain}";
                icon = "nextcloud";
                siteMonitor = "https://cloud.${domain}";
              };
            }
            {
              Open-WebUI = {
                href = "https://ai.${domain}";
                icon = "open-webui";
                siteMonitor = "https://ai.${domain}";
              };
            }
            {
              NocoDB = {
                href = "https://data.${domain}";
                icon = "nocodb";
                siteMonitor = "https://data.${domain}";
              };
            }
            {
              N8N = {
                href = "https://automation.${domain}";
                icon = "n8n";
                siteMonitor = "https://automation.${domain}";
              };
            }
          ];
        }
        {
          Services = [

            {
              Syncthing = {
                href = "https://backup.${domain}";
                icon = "syncthing";
                siteMonitor = "https://backup.${domain}";
              };
            }
            {
              "Home Assistant" = {
                href = "https://ha.${domain}";
                icon = "home-assistant";
                siteMonitor = "https://ha.${domain}";
              };
            }
            {
              ActualBudget = {
                href = "https://budget.${domain}";
                icon = "https://budget.${domain}/favicon.ico";
                siteMonitor = "https://budget.${domain}";
              };
            }
          ];
        }
        {
          Multimedia = [
            {
              Jellyfin = {
                icon = "jellyfin";
                href = "https://media.${domain}";
                siteMonitor = "https://media.${domain}";
              };
            }
            {
              Photos = {
                href = "https://photos.${domain}";
                icon = "photoprism";
                siteMonitor = "https://photos.${domain}";
              };
            }
          ];
        }
      ];

      # https://gethomepage.dev/latest/configs/docker/

      docker = { };

      # https://gethomepage.dev/latest/configs/bookmarks/

      bookmarks = [
        {
          Developer = [
            {
              Github = [{
                icon = "si-github";
                href = "https://github.com/";
              }];
            }
            {
              "Nixos Search" = [{
                icon = "si-nixos";
                href = "https://search.nixos.org/packages";
              }];
            }
            {
              "Nixos Wiki" = [{
                icon = "si-nixos";
                href = "https://nixos.wiki/";
              }];
            }
          ];
        }
      ];

    };
  };

}
