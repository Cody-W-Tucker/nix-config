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
              };
            }
          ];
        }
        {
          Services = [

            {
              Photos = {
                href = "https://photos.${domain}";
                icon = "photoprism";
              };
            }
            {
              Syncthing = {
                href = "https://backup.${domain}";
                icon = "syncthing";
              };
            }
            {
              HomeAssistant = {
                href = "https://ha.${domain}";
                icon = "homeAssistant";
              };
            }
            {
              NocoDB = {
                href = "https://data.${domain}";
                icon = "nocodb";
              };
            }
            {
              N8N = {
                href = "https://automation.${domain}";
                icon = "n8n";
              };
            }
            {
              ActualBudget = {
                href = "https://budget.${domain}";
                icon = "https://budget.${domain}/favicon.ico";
                siteMonitor = "https://budget.${domain}";
              };
            }
            {
              "Open-WebUI" = {
                href = "https://ai.${domain}";
                icon = "open-webui";
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
