{ config, pkgs, ... }:
{
  services = {
    grafana = {
      enable = true;
      provision.enable = true;
      settings = {
        analytics.reporting_enabled = false;
        server = {
          # Listening Address
          http_addr = "127.0.0.1";
          # and Port
          http_port = 3001;
          # Grafana needs to know on which domain and URL it's running
          domain = "monitoring.homehub.tv";
        };
      };
      provision.datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://127.0.0.1:${toString config.services.prometheus.port}";
          }
          {
            name = "Loki";
            type = "loki";
            url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          }
        ];
      };
    };
    prometheus = {
      enable = true;
      port = 9001;
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
        };
      };
      scrapeConfigs = [
        {
          job_name = "server";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
            }
          ];
        }
      ];
    };
    # loki = {
    #   enable = true;
    #   # Add config later

    # };
    # promtail = {
    #   enable = true;
    #   # Add config later
    # };
    nginx.virtualHosts."monitoring.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
      };
    };
  };
}
