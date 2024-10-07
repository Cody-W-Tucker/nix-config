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
          # {
          #   name = "Loki";
          #   type = "loki";
          #   url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
          # }
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
    loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_port = 3090;
        };

        common = {
          path_prefix = config.services.loki.dataDir;
          storage.filesystem = {
            chunks_directory = "${config.services.loki.dataDir}/chunks";
            rules_directory = "${config.services.loki.dataDir}/rules";
          };
          replication_factor = 1;
          ring = {
            kvstore.store = "inmemory";
            instance_addr = "127.0.0.1";
          };
        };

        ingester = {
          chunk_encoding = "snappy";
          lifecycler = {
            join_after = "0s"; # Added for quicker startup
          };
        };

        limits_config = {
          retention_period = "120h";
          ingestion_burst_size_mb = 16;
          reject_old_samples = true;
          reject_old_samples_max_age = "12h";
          split_queries_by_interval = "24h";
        };

        table_manager = {
          retention_deletes_enabled = true;
          retention_period = "120h";
        };

        compactor = {
          retention_enabled = true;
          compaction_interval = "10m";
          working_directory = "${config.services.loki.dataDir}/compactor";
          delete_request_cancel_period = "10m";
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
          delete_request_store = "filesystem";
        };

        schema_config.configs = [{
          from = "2024-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];

        query_range.cache_results = true;
      };
    };

    promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 3091;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
        };
        clients = [{
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
        }];
        scrape_configs = [{
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "server";
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }];
      };
      # extraFlags
    };

    nginx.virtualHosts."monitoring.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.settings.server.http_port}";
        proxyWebsockets = true;
        recommendedProxySettings = true;
        recommendedGzipSettings = false;
      };
      httpConfig = ''
        gzip on;
        gzip_static on;
        gzip_vary on;
        gzip_comp_level 5;
        gzip_min_length 256;
        gzip_proxied expired no-cache no-store private auth;
        gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
        gzip_buffers 64 8k;
      '';
    };
  };
}
