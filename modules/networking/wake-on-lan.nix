{
  # Wake-on-LAN, one feature with two sides:
  #   .target: the machine being woken (beast) accepts magic packets on its NIC.
  #   .waker:  a host that sends the packet and waits for the target to answer.
  # The waker is declared but deliberately NOT included by any host (it was
  # never enabled); include den.aspects.wake-on-lan.waker from modules/hosts/nas.nix
  # to turn it on. Its unit is oneshot and has no wantedBy.
  den.aspects.wake-on-lan.target.nixos = {
    networking.interfaces.eno1.wakeOnLan = {
      enable = true;
      policy = [ "magic" ];
    };
  };

  den.aspects.wake-on-lan.waker.nixos =
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
