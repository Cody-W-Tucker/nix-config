{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.wake-beast;
  beastHost = "192.168.1.20";
  beastMac = "60:cf:84:7a:a3:4a";
  broadcastAddr = "192.168.1.255";
  readinessUrl = "http://${beastHost}:8081/v1/models";
  maxRetries = 30;
  retryDelay = 10;
in
{
  options.services.wake-beast.enable = lib.mkEnableOption "Wake Beast and wait for its inference endpoint";

  config = lib.mkIf cfg.enable {
    systemd.services.wake-beast = {
      description = "Wake Beast (WoL) and wait for inference readiness";
      documentation = [ "https://wiki.archlinux.org/title/Wake-on-LAN" ];
      serviceConfig.Type = "oneshot";
      path = [
        pkgs.wakeonlan
        pkgs.curl
      ];
      script = ''
        set -euo pipefail

        if curl -sf --max-time 5 "${readinessUrl}" > /dev/null 2>&1; then
          echo "Beast inference endpoint already ready; no WoL needed."
          exit 0
        fi

        echo "Sending WoL magic packet to ${beastMac} via ${broadcastAddr}"
        wakeonlan -i ${broadcastAddr} ${beastMac}

        for i in $(seq 1 ${toString maxRetries}); do
          if curl -sf --max-time 5 "${readinessUrl}" > /dev/null 2>&1; then
            echo "Beast inference endpoint ready after $((i * ${toString retryDelay})) seconds"
            exit 0
          fi
          sleep ${toString retryDelay}
        done

        echo "ERROR: Beast readiness check timed out after ${toString (maxRetries * retryDelay)} seconds" >&2
        exit 1
      '';
    };
  };
}
