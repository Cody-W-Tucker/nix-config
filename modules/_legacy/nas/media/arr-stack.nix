{
  config,
  lib,
  mkNginxVhost,
  ...
}:

let
  inherit (config.codyos.site) domain;
  confinedServices = [
    "prowlarr"
    "sonarr"
    "radarr"
    "readarr"
    "bazarr"
    "lidarr"
  ];
  # Indexer Manager (no group override — matches original)
  mediaServices = lib.remove "prowlarr" confinedServices;
  # Must match rpc-bind-address in transmission.nix.
  namespaceAddress = "192.168.15.1";
  # Bazarr has no settings.server.port option; its port is listenPort.
  mkConfinedVhost =
    name:
    mkNginxVhost (
      (
        if name == "bazarr" then
          {
            host = "bazarr.${domain}";
            port = config.services.bazarr.listenPort;
          }
        else
          { service = name; }
      )
      // {
        proxyHost = namespaceAddress;
      }
    );
in
{
  # The Arr-stack services run inside the wg VPN namespace (declared in
  # transmission.nix) so their traffic exits through the VPN. FlareSolverr is
  # the exception: it runs on the host network and Prowlarr reaches it at the
  # host-side wg-br bridge address (192.168.15.5:8191) — the LAN IP
  # (192.168.1.2) is not routed into the wg namespace. Because the namespace
  # OUTPUT kill switch drops new connections out the veth, the single host
  # 192.168.15.5/32 is allowlisted in vpnNamespaces.wg.allowedEgress
  # (transmission.nix); that is the only egress exception. The host firewall
  # only allows TCP 8191 on wg-br, so FlareSolverr stays unreachable from
  # outside the host/bridge. Host-side consumers (nginx, LAN clients) reach
  # confined services at the namespace address 192.168.15.1 via the port
  # mappings in transmission.nix.
  systemd.services = lib.genAttrs confinedServices (_: {
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
  });

  # FlareSolverr listens on the host network; the wg namespace reaches it
  # across the wg-br bridge at 192.168.15.5 (permitted as a /32 egress
  # exception via vpnNamespaces.wg.allowedEgress in transmission.nix). Only
  # open the port on that interface (not globally — do NOT use
  # services.flaresolverr.openFirewall, which would expose 8191 on every
  # interface).
  networking.firewall.interfaces.wg-br.allowedTCPPorts = [
    config.services.flaresolverr.port
  ];

  services =
    lib.genAttrs mediaServices (_: {
      enable = true;
      group = "media";
    })
    // {
      prowlarr.enable = true;
      flaresolverr.enable = true;

      # Every confined service above is proxied by nginx at the namespace
      # address instead of 127.0.0.1 (LAN access comes from the host port
      # mappings in transmission.nix). FlareSolverr runs on the host network
      # and needs no vhost; the wg namespace reaches it directly at the wg-br
      # bridge address. Ports are still derived from each service's NixOS
      # module options.
      nginx.virtualHosts = lib.mergeAttrsList (map mkConfinedVhost confinedServices);
    };

  nas.backups.sqlite = [
    {
      name = "radarr";
      source = "/var/lib/radarr/.config/Radarr/radarr.db";
    }
    {
      name = "sonarr";
      source = "/var/lib/sonarr/.config/NzbDrone/sonarr.db";
    }
    {
      name = "lidarr";
      source = "/var/lib/lidarr/.config/Lidarr/lidarr.db";
    }
    {
      name = "readarr";
      source = "/var/lib/readarr/readarr.db";
    }
    {
      name = "bazarr";
      source = "/var/lib/bazarr/db/bazarr.db";
    }
    {
      name = "prowlarr";
      source = "/var/lib/prowlarr/prowlarr.db";
    }
  ];
}
