{
  # Wake Beast (WoL) and wait for host availability. Declared but deliberately NOT
  # included by any host or role (it was never enabled); include den.aspects.wake-beast
  # from modules/hosts/nas.nix to turn it on. The unit is oneshot and has no wantedBy.
  den.aspects.wake-beast.nixos =
    { config, pkgs, ... }:
    let
      beastHost = config.codyos.site.hosts.beast.lan;
      beastMac = config.codyos.site.hosts.beast.mac;
      broadcastAddr = config.codyos.site.lan.broadcast;
      maxRetries = 30;
      retryDelay = 10;
    in
    {
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
