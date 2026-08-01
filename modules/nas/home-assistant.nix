{
  mkNginxVhost,
  pkgs,
  ...
}:

{
  services.home-assistant = {
    enable = true;
    package = pkgs.home-assistant.override {
      extraPackages = ps: [
        # Existing integrations
        ps.aiohue
        ps."starlink-grpc-core"
        ps."ha-philipsjs"

        # NAS service integrations (runtime deps for UI-paired integrations)
        ps."jellyfin-apiclient-python"
        ps.aiopyarr # Shared by sonarr, radarr, lidarr
        ps."transmission-rpc"
        ps.aioimmich
        ps.adguardhome
        ps.aiosyncthing
        ps."python-overseerr"
        ps.tailscale

        # Auto-discovery integrations (required since default_config is not enabled)
        ps.aiodhcpwatcher
        ps.aiodiscover
        ps."cached-ipaddress"
        ps."async-upnp-client"
        ps.aiousbwatcher
        ps.serialx
        ps.zeroconf

        # Bluetooth integration runtime dependencies (manifest-backed)
        ps.bleak
        ps."bleak-retry-connector"
        ps."bluetooth-adapters"
        ps."bluetooth-auto-recovery"
        ps."bluetooth-data-tools"
        ps."dbus-fast"
        ps.habluetooth
      ];
    };
    config = {
      # Allow editing from the web UI
      homeassistant = {
        name = "HomeHub";
        unit_system = "us_customary";
      };
      http = {
        use_x_forwarded_for = true;
        # Only trust nginx on loopback
        trusted_proxies = [ "127.0.0.1" ];
        server_host = "127.0.0.1";
      };
      mobile_app = { };
      prometheus = { };

      # Explicit discovery integrations (not included without default_config)
      dhcp = { };
      ssdp = { };
      usb = { };
      zeroconf = { };
      bluetooth = { };
    };
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "home-assistant.homehub.tv";
    port = 8123;
    proxyWebsockets = true;
  };
}
