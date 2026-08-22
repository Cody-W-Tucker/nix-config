{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.wake-beast;
  beastHost = "192.168.1.238";
  beastMac = "60:cf:84:7a:a3:4a";
  broadcastAddr = "192.168.1.255";
  maxRetries = 30;
  retryDelay = 10;
in
{
  options.services.wake-beast.enable = lib.mkEnableOption "Wake Beast and wait for host availability";

  config = lib.mkIf cfg.enable {
    systemd.services.wake-beast = {
      description = "Wake Beast (WoL) and wait for host availability";
      documentation = [ "https://wiki.archlinux.org/title/Wake-on-LAN" ];
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.wakeonlan
        pkgs.iputils
      ];
      script = ''
        set -euo pipefail

        if ping -c 1 -W 5 ${beastHost} > /dev/null 2>&1; then
          echo "Beast host already reachable; no WoL needed."
          exit 0
        fi

        echo "Sending WoL magic packet to ${beastMac} via ${broadcastAddr}"
        wakeonlan -i ${broadcastAddr} ${beastMac}

        for i in $(seq 1 ${toString maxRetries}); do
          if ping -c 1 -W 5 ${beastHost} > /dev/null 2>&1; then
            echo "Beast host reachable after $((i * ${toString retryDelay})) seconds"
            exit 0
          fi
          sleep ${toString retryDelay}
        done

        echo "ERROR: Beast host availability check timed out after ${
          toString (maxRetries * retryDelay)
        } seconds" >&2
        exit 1
      '';
    };
  };
}
