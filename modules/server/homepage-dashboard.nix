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
            columns = 2;
          };
          Tools = {
            style = "row";
            columns = 3;
          };
          Operations = {
            style = "row";
            columns = 3;
          };
        };
        headerStyle = "boxedWidgets";
        target = "_self";
        quicklaunch = {
          searchDescription = true;
          hideInternetSearch = false;
          showSearchSuggestions = true;
          hideVisitURL = false;
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
        {
          search = {
            provider = "google";
            focus = false;
            showSearchSuggestions = true;
            target = "_self";
          };
        }
        {
          openmeteo = {
            label = "Kearney";
            # Kearney Nebraska
            latitude = 40.699670;
            longitude = -99.010310;
            timezone = "America/Chicago";
            units = "imperial";
            cache = 5;
            format.maximumFractionDigits = 0;
          };
        }
      ];
      services = [
          {
          Business = [
            # {
            #   Nextcloud = {
            #     href = "https://cloud.${domain}";
            #     icon = "nextcloud";
            #     description = "Could storage and collaboration";
            #   };
            # }
            {
              mattermost = {
                href = "https://chat.${domain}";
                icon = "mattermost";
                description = "Open Sourced Slack";
              };
            }
            {
              NocoDB = {
                href = "https://data.${domain}";
                icon = "nocodb";
                description = "Open source Airtable alternative";
              };
            }
          ];
        }
        {
          Tools = [
            {
              Open-WebUI = {
                href = "https://ai.${domain}";
                icon = "open-webui";
                description = "AI chat interface";
              };
            }
            {
              ExcaliDraw = {
                href = "https://draw.${domain}";
                icon = "excalidraw";
                description = "Whiteboard drawings";
              };
            }
            {
              Stirling-PDF = {
                href = "https://pdf.${domain}";
                icon = "stirling-pdf";
                description = "PDF Editing";
              };
            }
          ];
        }
        {
          Operations = [
            {
              Qdrant = {
                href = "https://qdrant.${domain}/dashboard";
                icon = "https://qdrant.${domain}/dashboard/favicon.ico";
                description = "Vector search engine";
              };
            }
            {
              Grafana = {
                href = "https://monitoring.${domain}";
                icon = "grafana";
                description = "Metrics dashboard";
              };
            }
            {
              N8N = {
                href = "https://automation.${domain}";
                icon = "n8n";
                description = "Workflow automation";
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
              };
            }
            {
              Photos = {
                href = "https://photos.${domain}";
                icon = "immich";
                description = "Photo management";
              };
            }
            {
              Jellyfin = {
                icon = "jellyfin";
                href = "https://media.${domain}";
                description = "Media server";
              };
            }
          ];
        }
        {
          Read = [
            {
              Miniflux = {
                href = "https://rss.${domain}";
                icon = "miniflux";
                description = "RSS reader";
              };
            }
            {
              Hoarder = {
                href = "https://hoarder.${domain}";
                icon = "hoarder";
                description = "Link collector";
              };
            }
            {
              Paperless = {
                href = "https://paperless.${domain}";
                icon = "paperless";
                description = "Document Management";
              };
            }
          ];
        }
        {
          Media = [
            {
              Sonarr = {
                href = "https://sonarr.${domain}";
                icon = "sonarr";
                description = "Media Management";
              };
            }
            {
              Radarr = {
                href = "https://radarr.${domain}";
                icon = "radarr";
                description = "Media Management";
              };
            }
            {
              Prowlarr = {
                href = "https://prowlarr.${domain}";
                icon = "prowlarr";
                description = "Media Management";
              };
            }
            {
              ARM = {
                href = "https://arm.${domain}";
                icon = "https://arm.${domain}/static/img/favicon.png";
                description = "Automatic DVD Ripping Machine";
              };
            }
          ];
        }
        {
          Network = [
            {
              AdGuard = {
                href = "https://adguard.${domain}";
                icon = "adguard-home";
                description = "Network wide adblocking";
              };
            }
            {
              "Home Assistant" = {
                href = "http://192.168.254.38:8123/";
                icon = "home-assistant";
                description = "Open source home automation";
              };
            }
            {
              Syncthing = {
                href = "https://backup.${domain}";
                icon = "syncthing";
                description = "File synchronization";
              };
            }
          ];
        }
      ];
    };
  };
}
