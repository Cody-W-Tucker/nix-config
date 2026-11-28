{ den, ... }:
let
  loki = import ./_loki-endpoint.nix;
  nodePort = 9002;
  diskPort = 9633;
  forwardJournal = host: port: lib: {
    services.fluent-bit = {
      enable = true;
      settings.pipeline.outputs = lib.mkBefore [
        {
          name = "loki";
          match = "journal";
          inherit host port;
          labels = "job=systemd-journal,host=$hostname,unit=$systemd_unit,level=$level";
          line_format = "json";
        }
        {
          name = "loki";
          match = "egress";
          inherit host port;
          labels = "job=egress,host=$hostname,source=$egress,country=$country";
          line_format = "json";
        }
      ];
    };
  };
in
{
  den.default.includes = [ den.aspects.logging ];

  den.aspects = {
    beast.includes = [
      den.aspects.logging.desktop
      den.aspects.logging.forward-to-nas
    ];

    logging = {
      nixos =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          priorityToLevelScript = pkgs.writeText "fb-priority-to-level.lua" ''
            function priority_to_level(tag, timestamp, record)
              local map = {
                ["0"] = "emerg",  ["1"] = "alert", ["2"] = "crit",
                ["3"] = "err",    ["4"] = "warning", ["5"] = "notice",
                ["6"] = "info",   ["7"] = "debug",
              }
              record["level"] = map[tostring(record["priority"])] or "info"
              return 2, timestamp, record
            end
          '';
        in
        {
          services = {
            prometheus.exporters = {
              node = {
                enable = true;
                enabledCollectors = lib.mkBefore [ "systemd" ];
                port = nodePort;
              };
              smartctl = {
                enable = true;
                port = diskPort;
                user = "root";
                group = "root";
              };
            };

            fluent-bit = {
              settings = {
                service = {
                  flush = 1;
                  log_level = "info";
                };
                pipeline = {
                  inputs = lib.mkBefore [
                    {
                      name = "systemd";
                      tag = "journal";
                      read_from_tail = true;
                      strip_underscores = true;
                      lowercase = true;
                    }
                  ];
                  filters = [
                    {
                      name = "lua";
                      match = "journal";
                      script = toString priorityToLevelScript;
                      call = "priority_to_level";
                    }
                  ];
                };
              };
            };
          };

          networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
            config.services.prometheus.exporters.smartctl.port
          ];
        };

      forward-to-nas.nixos = { lib, ... }: forwardJournal loki.host loki.port lib;
      forward-local.nixos =
        { config, lib, ... }:
        forwardJournal "127.0.0.1" config.services.loki.configuration.server.http_listen_port lib;

      desktop = {
        prometheus-targets =
          { host, ... }:
          {
            host = host.name;
            ports = {
              client = nodePort;
              smartctl = diskPort;
            };
          };
        nixos =
          { config, ... }:
          {
            networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
              config.services.prometheus.exporters.node.port
            ];
          };
      };
    };
  };
}
