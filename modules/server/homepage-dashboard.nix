let

  domain = "homehub.tv";

in
{

  services = {
    nginx.virtualHosts."homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://server:8082";
      };
    };

    homepage-dashboard = {
      enable = true;
      listenPort = 8082;
      openFirewall = true;
      settings = {
        title = "HomeHub.tv";
        cardBlur = "sm";
        layout = {
          Business = {
            style = "row";
            columns = 3;
          };
        };
        headerStyle = "boxedWidgets";
        target = "_self";
        quicklaunch = {
          searchDescription = true;
          hideInternetSearch = false;
          showSearchSuggestions = false;
          hideVisitURL = true;
          provider = "google";
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
            label = "HDD";
            disk = "/mnt/hdd";
          };
        }
      ];
      services = [
        {
          Business = [
            {
              Nextcloud = {
                href = "https://cloud.${domain}";
                icon = "nextcloud";
                description = "Could storage and collaboration";
                siteMonitor = "https://cloud.${domain}";
              };
            }
            {
              Open-WebUI = {
                href = "https://ai.${domain}";
                icon = "open-webui";
                description = "Open source web interface for interacting with AI models";
                siteMonitor = "https://ai.${domain}";
              };
            }
            {
              NocoDB = {
                href = "https://data.${domain}";
                icon = "nocodb";
                description = "Open source Airtable alternative";
                siteMonitor = "https://data.${domain}";
              };
            }
          ];
        }
        {
          Personal = [
            {
              ActualBudget = {
                href = "https://budget.${domain}";
                icon = "https://budget.${domain}/favicon.ico";
                description = "Personal budgeting tool";
                siteMonitor = "https://budget.${domain}";
              };
            }
            {
              "Home Assistant" = {
                href = "http://192.168.254.38:8123/";
                icon = "home-assistant";
                description = "Open source home automation";
                siteMonitor = "http://192.168.254.38:8123/";
              };
            }
            {
              Syncthing = {
                href = "https://backup.${domain}";
                icon = "syncthing";
                description = "File synchronization";
                siteMonitor = "https://backup.${domain}";
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
                description = "Media server";
                siteMonitor = "https://media.${domain}";
              };
            }
            {
              Photos = {
                href = "https://photos.${domain}";
                icon = "photoprism";
                description = "Photo management";
                siteMonitor = "https://photos.${domain}";
              };
            }
            {
              ARM = {
                href = "https://arm.${domain}";
                icon = "https://arm.${domain}/static/img/favicon.png";
                description = "Automatic DVD Ripping Machine";
                siteMonitor = "https://arm.${domain}";
              };
            }
          ];
        }
        {
          Operations = [
            {
              Grafana = {
                href = "https://monitoring.${domain}";
                icon = "grafana";
                description = "Metrics dashboard";
                siteMonitor = "https://monitoring.${domain}";
              };
            }
            {
              Metabase = {
                href = "https://bi.${domain}";
                icon = "metabase";
                description = "Business intelligence";
                siteMonitor = "https://bi.${domain}";
              };
            }
            {
              N8N = {
                href = "https://automation.${domain}";
                icon = "n8n";
                description = "Workflow automation";
                siteMonitor = "https://automation.${domain}";
              };
            }
          ];
        }
      ];
    };
  };
}
