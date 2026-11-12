# Host telemetry shared by every host: the node exporter (scraped by the NAS
# Prometheus) and Fluent Bit shipping the systemd journal to the NAS Loki.
# Host-specific inputs and outputs (e.g. NAS nginx logs) are appended by the
# owning module; list settings concatenate after the shared entries (mkBefore).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The NAS runs Loki itself; every other host ships to it by hostname.
  lokiIsLocal = config.services.loki.enable;
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
      port = 9002;
    };

    fluent-bit = {
      enable = true;
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
          outputs = lib.mkBefore [
            {
              name = "loki";
              match = "journal";
              host = if lokiIsLocal then "127.0.0.1" else "nas";
              port = if lokiIsLocal then config.services.loki.configuration.server.http_listen_port else 3090;
              labels = "job=systemd-journal,host=$hostname,unit=$systemd_unit,level=$level";
              line_format = "json";
            }
          ];
        };
      };
    };
  };
}
