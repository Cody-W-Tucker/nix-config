{ config, ... }:
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
          Tools = {
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
          Tools = [
            # {
            #   Nextcloud = {
            #     href = "https://cloud.${domain}";
            #     icon = "nextcloud";
            #     description = "Could storage and collaboration";
            #   };
            # }
            {
              Open-WebUI = {
                href = "https://ai.${domain}";
                icon = "open-webui";
                description = "AI chat interface";
              };
            }
            {
              Paperless = {
                href = "https://paperless.${domain}";
                icon = "paperless";
                description = "Document Management";
              };
            }
            # {
            #   NocoDB = {
            #     href = "https://data.${domain}";
            #     icon = "nocodb";
            #     description = "Open source Airtable alternative";
            #   };
            # }
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
                description = "Personal budgeting tool";
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
        {
          Multimedia = [
            {
              Jellyfin = {
                icon = "jellyfin";
                href = "https://media.${domain}";
                description = "Media server";
              };
            }
            # {
            #   Photos = {
            #     href = "https://photos.${domain}";
            #     icon = "photoprism";
            #     description = "Photo management";
            #   };
            # }
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
          Content = [
            {
              Miniflux = {
                href = "https://rss.${domain}";
                icon = "miniflux";
                description = "RSS reader";
              };
            }
            {
              Calibre = {
                href = "https://ebook.${domain}";
                icon = "calibre";
                description = "Ebook reader";
              };
            }
            {
              Hoarder = {
                href = "https://hoarder.${domain}";
                icon = "hoarder";
                description = "Link collector";
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
            # {
            #   Metabase = {
            #     href = "https://bi.${domain}";
            #     icon = "metabase";
            #     description = "Business intelligence";
            #   };
            # }
          ];
        }
      ];
    };
  };
}
