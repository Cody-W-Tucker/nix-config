{
  config,
  mkNginxVhost,
  ...
}:

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
  systemd.services = {
    prowlarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    sonarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    radarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    readarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    bazarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    lidarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
  };

  # FlareSolverr listens on the host network; the wg namespace reaches it
  # across the wg-br bridge at 192.168.15.5 (permitted as a /32 egress
  # exception via vpnNamespaces.wg.allowedEgress in transmission.nix). Only
  # open the port on that interface (not globally — do NOT use
  # services.flaresolverr.openFirewall, which would expose 8191 on every
  # interface).
  networking.firewall.interfaces.wg-br.allowedTCPPorts = [
    config.services.flaresolverr.port
  ];

  services = {
    sonarr = {
      enable = true;
      group = "media";
    };
    radarr = {
      enable = true;
      group = "media";
    };
    readarr = {
      enable = true;
      group = "media";
    };
    bazarr = {
      enable = true;
      group = "media";
    };
    lidarr = {
      enable = true;
      group = "media";
    };
    # Indexer Manager (no group override — matches original)
    prowlarr.enable = true;
    flaresolverr.enable = true;

    # Every confined service above is proxied by nginx at the namespace
    # address instead of 127.0.0.1 (LAN access comes from the host port
    # mappings in transmission.nix). FlareSolverr runs on the host network
    # and needs no vhost; the wg namespace reaches it directly at the wg-br
    # bridge address. Ports are still derived from each service's NixOS
    # module options.
    nginx.virtualHosts =
      mkNginxVhost {
        service = "sonarr";
        proxyHost = "192.168.15.1";
      }
      // mkNginxVhost {
        service = "radarr";
        proxyHost = "192.168.15.1";
      }
      // mkNginxVhost {
        service = "readarr";
        proxyHost = "192.168.15.1";
      }
      // mkNginxVhost {
        host = "bazarr.homehub.tv";
        port = config.services.bazarr.listenPort;
        proxyHost = "192.168.15.1";
      }
      // mkNginxVhost {
        service = "lidarr";
        proxyHost = "192.168.15.1";
      }
      // mkNginxVhost {
        service = "prowlarr";
        # Must match rpc-bind-address in transmission.nix.
        proxyHost = "192.168.15.1";
      };
  };
}
