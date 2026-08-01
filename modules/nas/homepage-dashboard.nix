{
  mkNginxVhost,
  ...
}:

let
  domain = "homehub.tv";
in
{

  services = {
    nginx.virtualHosts = mkNginxVhost {
      host = "homehub.tv";
      port = 8082;
      proxyWebsockets = true;
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
            {
              Open-WebUI = {
                href = "https://ai.${domain}";
                icon = "open-webui";
                description = "AI Chat Interface";
              };
            }
            {
              Paperless = {
                href = "https://paperless.${domain}";
                icon = "paperless";
                description = "Document Management";
              };
            }
            {
              ExcaliDraw = {
                href = "https://draw.${domain}";
                icon = "excalidraw";
                description = "Whiteboard";
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
              ActualBudget = {
                href = "https://budget.${domain}";
                icon = "https://budget.${domain}/favicon.ico";
                description = "Personal Budget";
              };
            }
            {
              Karakeep = {
                href = "https://karakeep.${domain}";
                icon = "karakeep";
                description = "Bookmark Manager";
              };
            }
            {
              HomeAssistant = {
                href = "https://home-assistant.${domain}";
                icon = "home-assistant";
                description = "Home Automation";
              };
            }
            {
              UptimeKuma = {
                href = "https://uptime.${domain}";
                icon = "uptime-kuma";
                description = "Uptime Monitoring";
              };
            }
            {
              LlamaSwap = {
                href = "http://nas:8081";
                icon = "ollama";
                description = "LLM Model Router";
              };
            }
          ];
        }
        {
          Consume = [
            {
              Jellyfin = {
                icon = "jellyfin";
                href = "https://media.${domain}";
                description = "Media Server";
              };
            }
            {
              Navidrome = {
                href = "https://music.${domain}";
                icon = "navidrome";
                description = "Music Server";
              };
            }
            {
              CalibreWeb = {
                href = "https://books.${domain}";
                icon = "calibre";
                description = "Ebook Reader Software";
              };
            }
            {
              Miniflux = {
                href = "https://rss.${domain}";
                icon = "miniflux";
                description = "RSS Reader";
              };
            }
          ];
        }
        {
          Collect = [
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
              Readarr = {
                href = "https://readarr.${domain}";
                icon = "readarr";
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
              NASSyncthing = {
                href = "https://nas-syncthing.${domain}";
                icon = "syncthing";
                description = "File Synchronization - NAS";
              };
            }
            {
              BeastSyncthing = {
                href = "https://beast-syncthing.${domain}";
                icon = "syncthing";
                description = "File Synchronization - Beast";
              };
            }
          ];
        }

      ];
    };
  };
}
