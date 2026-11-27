{ den, ... }:
let
  loki = import ./_loki-endpoint.nix;
  inherit (den.lib.policy) pipe;
in
{
  den.quirks.prometheus-targets.description = "Scrape endpoints advertised by selected exporter aspects.";
  den.policies.collect-prometheus-targets = { host, ... }: [
    (pipe.from "prometheus-targets" [ (pipe.collect ({ host, ... }: true)) ])
  ];
  den.schema.host.includes = [ den.policies.collect-prometheus-targets ];
  den.aspects.nas.includes = [ den.aspects.monitoring ];

  den.aspects.monitoring = {
    includes = [ den.aspects.logging.forward-local ];
    nixos =
      {
        config,
        lib,
        mkNginxVhost,
        prometheus-targets,
        ...
      }:

      let
        inherit (config.codyos.site) domain;
        advertised = lib.sort (a: b: a.host < b.host) prometheus-targets;
        targetsFor =
          job:
          lib.concatMap (
            target:
            lib.optional (target.ports ? ${job}) {
              targets = [ "${target.host}:${toString target.ports.${job}}" ];
              labels.host = target.host;
            }
          ) advertised;
        resticBackup = config.services.restic.backups.nas-files;
        resticPasswordFile =
          if resticBackup.passwordFile == null then
            throw "The Restic exporter requires nas-files.passwordFile"
          else
            resticBackup.passwordFile;
      in
      {
        codyos.homepage.cards.Grafana = {
          group = "Network";
          order = 10;
          card = {
            href = "https://monitoring.${domain}";
            icon = "grafana";
            description = "Logging & Dashboard";
          };
        };

        services = {
          grafana = {
            enable = true;
            provision.enable = true;
            settings = {
              analytics.reporting_enabled = false;
              security.secret_key = "SW2YcwTIb9zpOOhoPsMm";
              server = {
                http_addr = "127.0.0.1";
                http_port = 3001;
                domain = "monitoring.${domain}";
                root_url = "https://monitoring.${domain}";
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
                {
                  name = "Loki";
                  type = "loki";
                  uid = "loki";
                  url = "http://localhost:${toString config.services.loki.configuration.server.http_listen_port}";
                }
              ];
            };
          };
          prometheus = {
            enable = true;
            extraFlags = [ "--web.enable-remote-write-receiver" ];
            port = 9001;
            exporters = {
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
                  namespaces = [
                    {
                      name = "nginxlog";
                      format = ''$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"'';
                      source.files = [ "/var/log/nginx/access.log" ];
                    }
                  ];
                };
              };
              restic = {
                enable = true;
                inherit (resticBackup) repository;
                passwordFile = resticPasswordFile;
                listenAddress = "127.0.0.1";
                refreshInterval = 3600;
                user = "root";
                group = "root";
              };
              zfs = {
                enable = true;
                pools = [ "backup" ];
                listenAddress = "127.0.0.1";
                port = 9134;
                user = "root";
                group = "root";
                extraFlags = [
                  "--collector.dataset-snapshot"
                  "--properties.dataset-snapshot=creation"
                  "--collector.pool"
                  "--properties.pool=health,allocated,free,size"
                  "--no-collector.dataset-filesystem"
                  "--no-collector.dataset-volume"
                ];
              };
            };
            scrapeConfigs = [
              {
                job_name = "server";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
                    labels = {
                      host = "${config.networking.hostName}";
                    };
                  }
                ];
              }
              {
                job_name = "client";
                static_configs = targetsFor "client";
              }
              {
                job_name = "smartctl";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}" ];
                    labels = {
                      host = "${config.networking.hostName}";
                    };
                  }
                ]
                ++ targetsFor "smartctl";
              }
              {
                job_name = "nvidia-gpu";
                static_configs = targetsFor "nvidia-gpu";
              }
              {
                job_name = "nginx";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginx.port}" ];
                    labels = {
                      host = "${config.networking.hostName}";
                    };
                  }
                ];
              }
              {
                job_name = "nginx-logs";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.nginxlog.port}" ];
                    labels = {
                      host = "${config.networking.hostName}";
                    };
                  }
                ];
              }
              {
                job_name = "restic";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.restic.port}" ];
                    labels = {
                      host = "${config.networking.hostName}";
                    };
                  }
                ];
              }
              {
                job_name = "zfs-backup";
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.zfs.port}" ];
                    labels = {
                      host = "${config.networking.hostName}";
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
                http_listen_port = loki.port;
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
                  join_after = "0s";
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
              ingester = {
                max_block_duration = "5m";
                lifecycler = {
                  ring = {
                    kvstore = {
                      store = "inmemory";
                    };
                    replication_factor = 1;
                  };
                };
              };
              memberlist = {
                bind_addr = [ "127.0.0.1" ];
                bind_port = 7946;
              };
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
                  host = "${config.networking.hostName}";
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

          fluent-bit.settings.pipeline = {
            inputs = [
              {
                name = "tail";
                tag = "nginx.access";
                path = "/var/log/nginx/access.log";
                read_from_head = false;
              }
            ];
            outputs = [
              {
                name = "loki";
                match = "nginx.access";
                host = "127.0.0.1";
                port = config.services.loki.configuration.server.http_listen_port;
                labels = "job=nginx-access,host=${config.networking.hostName}";
                line_format = "json";
              }
            ];
          };

          nginx.virtualHosts = mkNginxVhost {
            host = "monitoring.${domain}";
            port = config.services.grafana.settings.server.http_port;
            proxyWebsockets = true;
          };
        };

        systemd.services.fluent-bit.serviceConfig.SupplementaryGroups = [ "nginx" ];

        systemd.services.prometheus-restic-exporter = {
          unitConfig = {
            ConditionPathIsMountPoint = [ "/mnt/backup/backups" ];
            RequiresMountsFor = [ resticBackup.repository ];
          };
          serviceConfig = {
            DynamicUser = lib.mkForce false;
          };
        };

        systemd.services.prometheus-zfs-exporter.serviceConfig.DynamicUser = lib.mkForce false;

        networking.firewall.allowedTCPPorts = [
          config.services.loki.configuration.server.http_listen_port
          9001
        ];
      };
  };
}
