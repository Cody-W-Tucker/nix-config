{ pkgs, ... }:

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
  # Monitoring configuration
  services = {
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
    };

    fluent-bit = {
      enable = true;
      settings = {
        service = {
          flush = 1;
          log_level = "info";
        };
        pipeline = {
          filters = [
            {
              name = "lua";
              match = "journal";
              script = toString priorityToLevelScript;
              call = "priority_to_level";
            }
          ];
          outputs = [
            {
              name = "loki";
              match = "journal";
              host = "nas";
              port = 3090;
              labels = "job=systemd-journal,host=$hostname,unit=$systemd_unit,level=$level";
              line_format = "json";
            }
          ];
        };
      };
    };
  };

  # Open port for Loki
  networking.firewall.allowedTCPPorts = [ 9002 ];
}
