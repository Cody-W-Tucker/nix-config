let
  domain = "homehub.tv";
in
{

  services = {
    nginx.virtualHosts."homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8082";
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
            columns = 4;
          };
          Tools = {
            style = "row";
            columns = 4;
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
            label = "HDD";
            disk = "/mnt/hdd";
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
                description = "Open source Airtable";
              };
            }
            {
              N8N = {
                href = "https://automation.${domain}";
                icon = "n8n";
                description = "Automation";
              };
            }
            {
              Open-WebUI = {
                href = "https://ai.${domain}";
                icon = "open-webui";
                description = "AI Chat Interface";
              };
            }
          ];
        }
        {
          Tools = [
            {
              Qdrant = {
                href = "https://qdrant.${domain}/dashboard";
                icon = "https://qdrant.${domain}/dashboard/favicon.ico";
                description = "Vector DB";
              };
            }
            {
              Grafana = {
                href = "https://monitoring.${domain}";
                icon = "grafana";
                description = "Logging & Dashboard";
              };
            }
            {
              ExcaliDraw = {
                href = "https://draw.${domain}";
                icon = "excalidraw";
                description = "Whiteboard";
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
          Personal = [
            {
              ActualBudget = {
                href = "https://budget.${domain}";
                icon = "https://budget.${domain}/favicon.ico";
                description = "Personal Budget";
              };
            }
            {
              Photos = {
                href = "https://photos.${domain}";
                icon = "immich";
                description = "Photo Management";
              };
            }
            {
              Jellyfin = {
                icon = "jellyfin";
                href = "https://media.${domain}";
                description = "Media Server";
              };
            }
            {
              Jellyseerr = {
                icon = "jellyseerr";
                href = "https://request.${domain}";
                description = "Request Media Service";
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
                description = "RSS Reader";
              };
            }
            {
              Hoarder = {
                href = "https://hoarder.${domain}";
                icon = "hoarder";
                description = "Link Collector";
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
                description = "Network Wide Adblocking";
              };
            }
            {
              "Home Assistant" = {
                href = "http://192.168.254.38:8123/";
                icon = "home-assistant";
                description = "Open Source Home Automation";
              };
            }
            {
              Syncthing = {
                href = "https://backup.${domain}";
                icon = "syncthing";
                description = "File Synchronization";
              };
            }
          ];
        }
      ];
    };
  };
}
