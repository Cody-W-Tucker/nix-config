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
          root_url = "https://monitoring.homehub.tv";
        };
      };
      provision.datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString config.services.prometheus.port}";
          }
          {
            name = "Tempo";
            type = "tempo";
            uid = "tempo";
            url = "http://localhost:${toString config.services.tempo.settings.server.http_listen_port}";
          }
        ];
      };
    };
    prometheus = {
      enable = true;
      extraFlags = [ "--web.enable-remote-write-receiver" ];
      port = 9001;
      exporters = {
        node = {
          enable = true;
          enabledCollectors = [ "systemd" ];
          port = 9002;
        };
        nginx = {
          enable = true;
          port = 9115;
          scrapeUri = "http://127.0.0.1:9114/nginx_status";
        };
        nginxlog = {
          enable = true;
          group = "nginx";
          settings = {
            consul.enable = false;
            namespaces = [{
              name = "nginxlog";
              format = ''$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"'';
              source.files = [ "/var/log/nginx/access.log" ];
            }];
          };
        };
      };
      scrapeConfigs = [
        {
          job_name = "server";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
              labels = {
                host = "server";
              };
            }
          ];
        }
        {
          job_name = "client";
          static_configs = [
            {
              targets = [ "beast:9002" ];
              labels = {
                host = "beast";
              };
            }
            {
              targets = [ "aiserver:9002" ];
              labels = {
                host = "aiserver";
              };
            }
          ];
        }
        {
          job_name = "smartctl";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ];
              labels = {
                host = "server";
              };
            }
            {
              targets = [ "beast:9633" ];
              labels = {
                host = "beast";
              };
            }
            {
              targets = [ "aiserver:9633" ];
              labels = {
                host = "aiserver";
              };
            }
          ];
        }
        {
          job_name = "nvidia-gpu";
          static_configs = [
            {
              targets = [ "beast:9835" ];
              labels = {
                host = "beast";
              };
            }
          ];
        }
        {
          job_name = "nginx";
          static_configs = [
            {
              targets = [ "127.0.0.1:9115" ];
              labels = {
                host = "server";
              };
            }
          ];
        }
        {
          job_name = "nginx-logs";
          static_configs = [
            {
              targets = [ "127.0.0.1:9117" ];
              labels = {
                host = "server";
              };
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
          http_listen_address = "0.0.0.0";
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

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        query_range.cache_results = true;
      };
    };

    tempo = {
      enable = true;
      settings = {
        multitenancy_enabled = false;
        stream_over_http_enabled = true;
        server = {
          http_listen_address = "127.0.0.1";
          http_listen_port = 3200;
          grpc_listen_port = 9096;
        };
        distributor.receivers.otlp.protocols = {
          grpc.endpoint = "127.0.0.1:4327";
          http.endpoint = "127.0.0.1:4328";
        };
        ingester.max_block_duration = "5m";
        compactor.compaction = {
          block_retention = "168h";
          compacted_block_retention = "1h";
        };
        metrics_generator = {
          ring = {
            kvstore.store = "inmemory";
            instance_addr = "127.0.0.1";
          };
          processor.local_blocks.filter_server_spans = false;
          registry.external_labels = {
            source = "tempo";
            host = "server";
          };
          storage = {
            path = "/var/lib/tempo/generator/wal";
            remote_write = [
              {
                url = "http://127.0.0.1:${toString config.services.prometheus.port}/api/v1/write";
                send_exemplars = true;
              }
            ];
          };
          traces_storage.path = "/var/lib/tempo/generator/traces";
        };
        overrides.defaults.metrics_generator.processors = [
          "local-blocks"
          "service-graphs"
          "span-metrics"
        ];
        storage.trace = {
          backend = "local";
          wal.path = "/var/lib/tempo/wal";
          local.path = "/var/lib/tempo/traces";
        };
      };
    };

    opentelemetry-collector = {
      enable = true;
      settings = {
        receivers.otlp.protocols = {
          grpc.endpoint = "0.0.0.0:4317";
          http.endpoint = "0.0.0.0:4318";
        };
        processors.batch = { };
        exporters.otlp = {
          endpoint = "127.0.0.1:4327";
          tls.insecure = true;
        };
        service = {
          pipelines.traces = {
            receivers = [ "otlp" ];
            processors = [ "batch" ];
            exporters = [ "otlp" ];
          };
          telemetry.logs.level = "warn";
        };
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
        clients = [
          {
            url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
          }
        ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = "server";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
          {
            job_name = "nginx-access";
            static_configs = [
              {
                targets = [ "localhost" ];
                labels = {
                  job = "nginx-access";
                  host = "server";
                  __path__ = "/var/log/nginx/access.log";
                };
              }
            ];
          }
        ];
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
      };
      kTLS = true;
    };
  };

  users.users.promtail.extraGroups = [ "nginx" ];

  # Open port 3090 for Loki
  networking.firewall.allowedTCPPorts = [
    3090
    4317
    4318
    9001
  ];
}
