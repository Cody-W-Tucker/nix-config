{
  config,
  mkNginxVhost,
  ...
}:

{
  # All Arr-stack services run inside the wg VPN namespace (declared in
  # transmission.nix) so their traffic exits through the VPN. Host-side
  # consumers (nginx, LAN clients) reach them at the namespace address
  # 192.168.15.1 via the port mappings in transmission.nix.
  systemd.services = {
    prowlarr.vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };

    flaresolverr.vpnConfinement = {
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

    # Every service above is confined to the wg namespace, so nginx proxies to
    # the namespace address instead of 127.0.0.1 (LAN access comes from the
    # host port mappings in transmission.nix). Ports are still derived from
    # each service's NixOS module options.
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
