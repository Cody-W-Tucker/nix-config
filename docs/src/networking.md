# Networking and VPN

At home, the NAS answers the `homehub.tv` names. Away, Tailscale makes the home LAN reachable. The download apps on the NAS reach the internet only through a commercial VPN.

## Getting in

| Where | How |
| --- | --- |
| Home LAN | `nas`, `beast`, and `https://<app>.homehub.tv` |
| Away | Join Tailscale. The NAS routes the whole LAN, so LAN addresses and `homehub.tv` URLs work as at home. |
| SSH | `ssh nas`, keys only. From Kitty, use `ssh-` so yanks reach the local clipboard. |

Only over Tailscale: the Syncthing UIs, the [Hermes dashboard](hermes.md#open-the-dashboard), the NAS build cache.

On the NAS, five failed SSH logins ban an address for 24 h, growing with each repeat up to 7 days. LAN addresses are never banned. Beast uses fail2ban defaults.

## The VPN

Transmission and the Arr apps reach the internet only through the WireGuard tunnel. When the tunnel is down, they have no internet access; they never fall back to the home connection. Their web UIs stay reachable at `sonarr.homehub.tv` and so on.

In the media apps' own settings, address each other as `192.168.15.1:<port>`, not `localhost`. Example: Jellyseerr → Sonarr is `192.168.15.1:8989`.

## Changing it

| To change | Edit |
| --- | --- |
| SSH, firewall, fail2ban, Tailscale (both hosts) | [`networking.nix`](../../modules/networking/networking.nix) |
| NAS address, Tailscale subnet route | [`modules/hosts/nas.nix`](../../modules/hosts/nas.nix) |
| VPN tunnel, ports reachable from the LAN, egress exceptions | [`transmission.nix`](../../modules/media/transmission.nix) |
| Which apps run behind the VPN | [`arr-stack.nix`](../../modules/media/arr-stack.nix) |
| DNS (the NAS resolves only through itself) | [`dns.nix`](../../modules/networking/dns.nix) |
