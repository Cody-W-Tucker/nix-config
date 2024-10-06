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
        server.http_listen_port = 3090;
        server.log_level = "warn";

        common = {
          path_prefix = config.services.loki.dataDir;
          storage.filesystem = {
            chunks_directory = "${config.services.loki.dataDir}/chunks";
            rules_directory = "${config.services.loki.dataDir}/rules";
          };
          ring = {
            kvstore = {
              store = "inmemory";
            };
            instance_addr = "127.0.0.1";
          };
        };

        schema_config = {
          configs = [{
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }];
        };

        ruler = {
          storage = {
            type = "local";
            local.directory = "${config.services.loki.dataDir}/ruler";
          };
          rule_path = "${config.services.loki.dataDir}/rules";
          alertmanager_url = "http://alertmanager.r";
        };

        ingester.chunk_encoding = "snappy";

        limits_config = {
          retention_period = "120h";
          ingestion_burst_size_mb = 16;
          reject_old_samples = true;
          reject_old_samples_max_age = "12h";
        };

        query_range.cache_results = true;
        limits_config.split_queries_by_interval = "24h";

        table_manager = {
          retention_deletes_enabled = true;
          retention_period = "120h";
        };

        storage_config = {
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
          };
        };

        compactor = {
          retention_enabled = true;
          compaction_interval = "10m";
          working_directory = "${config.services.loki.dataDir}/compactor";
          delete_request_cancel_period = "10m"; # don't wait 24h before processing the delete_request
          retention_delete_delay = "2h";
          retention_delete_worker_count = 150;
          delete_request_store = "filesystem";
        };
      };
    };

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
