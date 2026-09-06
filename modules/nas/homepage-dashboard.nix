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
                href = "https://chat.${domain}";
                icon = "open-webui";
                description = "AI Chat Interface";
              };
            }
            {
              Langfuse = {
                href = "https://langfuse.homehub.tv";
                icon = "https://langfuse.${domain}/favicon.ico";
                description = "LLM Observability";
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
          Tools = [
            {
              OpenCode = {
                href = "https://opencode.${domain}";
                icon = "opencode";
                description = "OpenCode Web";
              };
            }
            {
              Qdrant = {
                href = "https://qdrant.${domain}/dashboard";
                icon = "https://qdrant.${domain}/dashboard/favicon.ico";
                description = "Vector DB";
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
              Karakeep = {
                href = "https://karakeep.${domain}";
                icon = "karakeep";
                description = "Bookmark Manager";
              };
            }
            {
              UptimeKuma = {
                href = "https://uptime.${domain}";
                icon = "uptime-kuma";
                description = "Uptime Monitoring";
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
              Audiobookshelf = {
                href = "https://audiobooks.${domain}";
                icon = "audiobookshelf";
                description = "Audiobook and Podcast Server";
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
            {
              Dawarich = {
                href = "https://tracker.${domain}";
                icon = "dawarich";
                description = "Location Tracking";
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
              PaperlessGPT = {
                href = "https://paperless-gpt.${domain}";
                icon = "https://paperless-gpt.${domain}/favicon.ico";
                description = "AI Document Assistant";
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
                description = "Tv Show Search";
              };
            }
            {
              Radarr = {
                href = "https://radarr.${domain}";
                icon = "radarr";
                description = "Movie Search";
              };
            }
            {
              Readarr = {
                href = "https://readarr.${domain}";
                icon = "readarr";
                description = "Book Search";
              };
            }
            {
              Shelfmark = {
                href = "https://shelfmark.${domain}";
                icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/shelfmark.png";
                description = "Audiobook Search";
              };
            }
            {
              Lidarr = {
                href = "https://lidarr.${domain}";
                icon = "lidarr";
                description = "Music Search";
              };
            }
            {
              Bazarr = {
                href = "https://bazarr.${domain}";
                icon = "bazarr";
                description = "Subtitle Search";
              };
            }

          ];
        }
        {
          Network = [
            {
              Grafana = {
                href = "https://monitoring.${domain}";
                icon = "grafana";
                description = "Logging & Dashboard";
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
            {
              HomeAssistant = {
                href = "https://home-assistant.${domain}";
                icon = "home-assistant";
                description = "Home Automation";
              };
            }
          ];
        }

      ];
    };
  };
}
