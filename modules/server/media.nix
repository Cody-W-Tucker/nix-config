{ pkgs, ... }:
{
  # Media Management
  services = {
    jellyfin = {
      enable = true;
      group = "media";
    };

    jellyseerr = {
      enable = true;
    };

    sonarr = {
      enable = true;
      group = "media";
    };

    radarr = {
      enable = true;
      group = "media";
    };

    # Indexer Manager
    prowlarr = {
      enable = true;
    };

    transmission = {
      enable = true;
      group = "media";
      openRPCPort = true; # Allows Sonarr/Radarr to connect
      openPeerPorts = false; # Allows torrent peers to connect
      settings = {
        download-dir = "/mnt/hdd/Media/Downloads"; # Adjust as needed
        incomplete-dir = "/mnt/hdd/Media/Downloads/incomplete";
        incomplete-dir-enabled = true;
        umask = 2; # Group write permissions (so Sonarr/Radarr can move files)
        dht-enabled = true;
        encryption = 1; # Prefer encrypted peers
        download-queue-enabled = true;
        download-queue-size = 10;
        anti-brute-force-enabled = true;
        anti-brute-force-threshold = 10;
        blocklist-enabled = true;
        blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

        # Download Schedule
        alt-speed-enabled = true;         # Enable alternative speed limits
        alt-speed-down = 256;               # KB/s download during restricted hours
        alt-speed-up = 13;                 # KB/s upload during restricted hours
        alt-speed-time-enabled = true;    # Enable scheduled speed limit
        alt-speed-time-begin = 480;       # Start at 8:00 (8am), in minutes after midnight
        alt-speed-time-end = 1380;        # End at 22:00 (11pm), in minutes after midnight
        alt-speed-time-day = 126;         # Monday–Saturday only

        # VPN
        rpc-whitelist-enabled = true;
        rpc-whitelist = "192.168.15.5";
        rpc-authentication-required = true;
        rpc-bind-address = "192.168.15.1"; # Bind RPC/WebUI to VPN network namespace address
        bind-address-ipv4 = "192.168.15.1";
        bind-address-ipv6 = ""; # or "" if no IPv6 in VPN namespace

        # Disable UPnP and NAT-PMP to prevent port forwarding leaks
        port-forwarding-enabled = false;
        upnp-enabled = false;
        natpmp-enabled = false;
      };
    };
  };
  # Define VPN network namespace
  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = /. + "/secrets/wg0.conf";
    accessibleFrom = [
      "192.168.0.0/24"
    ];
    portMappings = [
      { from = 9091; to = 9091; }
    ];
    openVPNPorts = [{
      port = 60729;
      protocol = "both";
    }];
  };

  # Add systemd service to VPN network namespace
  systemd.services.transmission.vpnConfinement = {
    enable = true;
    vpnNamespace = "wg";
  };

    # NGINX
  services.nginx = {
    virtualHosts = {
      "media.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
        };
      };
      "request.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          proxyPass = "http://127.0.0.1:5055";
          proxyWebsockets = true;
        };
      };
      "prowlarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:9696";
        };
      };
      "radarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:7878";
        };
      };
      "sonarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://127.0.0.1:8989";
        };
      };
    };
  };

  # Syncthing backup TODO: Remove in favor of Restic backups
  # services.syncthing.settings.folders."media" = {
  #   path = "/mnt/hdd/Media";
  #   devices = [ "server" "workstation" ];
  # };

  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];

  # 1. enable vaapi on OS-level
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver # previously vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      intel-media-sdk # QSV up to 11th gen
    ];
  };
}
