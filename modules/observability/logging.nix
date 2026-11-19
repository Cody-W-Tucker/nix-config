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
        # Connection records split out of the journal by egress-audit.nix.
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
  # Host telemetry shared by every host: the node and smartctl exporters (scraped by the NAS
  # Prometheus) and the journal input. Shipping requires an explicit forwarding aspect.
  # Host-specific inputs and outputs (e.g. NAS nginx logs) are appended by the
  # owning module; list settings concatenate after the shared entries (mkBefore).
  den.aspects.logging.nixos =
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
        prometheus.exporters.node = {
          enable = true;
          enabledCollectors = lib.mkBefore [ "systemd" ];
          port = nodePort;
        };

        prometheus.exporters.smartctl = {
          enable = true;
          port = diskPort;
          user = "root";
          group = "root";
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

      # smartctl exporter: scraped by the NAS Prometheus over Tailscale (localhost on the NAS).
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        config.services.prometheus.exporters.smartctl.port
      ];
    };

  den.aspects.logging.forward-to-nas.nixos = { lib, ... }: forwardJournal loki.host loki.port lib;
  den.aspects.logging.forward-local.nixos =
    { config, lib, ... }:
    forwardJournal "127.0.0.1" config.services.loki.configuration.server.http_listen_port lib;

  # Open and advertise the desktop exporter endpoints for remote scraping.
  den.aspects.logging.desktop.prometheus-targets =
    { host, ... }:
    {
      host = host.name;
      ports = {
        client = nodePort;
        smartctl = diskPort;
      };
    };
  den.aspects.logging.desktop.nixos =
    { config, ... }:

    {
      # The shared node exporter is scraped by the NAS Prometheus over Tailscale.
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
        config.services.prometheus.exporters.node.port
      ];
    };

  den.default.includes = [ den.aspects.logging ];
}
