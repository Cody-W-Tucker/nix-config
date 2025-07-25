let
  domain = "homehub.tv";
in
{

  services = {
    nginx.virtualHosts."homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:8082";
      };
      kTLS = true;
    };

    homepage-dashboard = {
      enable = true;
      listenPort = 8082;
      openFirewall = false;
      allowedHosts = "homehub.tv";
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
            disk = "/mnt/media";
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
              N8N = {
                href = "https://automation.${domain}";
                icon = "n8n";
                description = "Automation";
              };
            }
            {
              Supabase = {
                href = "https://studio.${domain}";
                icon = "supabase";
                description = "BaaS";
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
              ActualBudget = {
                href = "https://budget.${domain}";
                icon = "https://budget.${domain}/favicon.ico";
                description = "Personal Budget";
              };
            }
            {
              Stirling-PDF = {
                href = "https://pdf.${domain}";
                icon = "stirling-pdf";
                description = "PDF Editing";
              };
            }
            {
              Penpot = {
                href = "https://design.${domain}";
                icon = "penpot";
                description = "Open Source Figma Alternative";
              };
            }
          ];
        }
        {
          View = [
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
            {
              Photos = {
                href = "https://photos.${domain}";
                icon = "immich";
                description = "Photo Management";
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
          Manage = [
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
              Lidarr = {
                href = "https://lidarr.${domain}";
                icon = "lidarr";
                description = "Media Management";
              };
            }
            {
              Bazarr = {
                href = "https://bazarr.${domain}";
                icon = "bazarr";
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
                href = "http://homeassistant:8123/";
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
