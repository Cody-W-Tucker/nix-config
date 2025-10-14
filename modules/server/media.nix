{ pkgs, config, ... }:
{
  # Folder structure
  systemd.tmpfiles.rules = [
    # Set main media directory
    "d /mnt/media/Media 2775 root media - -"
    # Set subdirectories with setgid for group inheritance
    "d /mnt/media/Media/Books 2775 root media - -"
    "d /mnt/media/Media/Channels 2775 root media - -"
    "d /mnt/media/Media/Downloads 2775 root media - -"
    "d /mnt/media/Media/Movies 2775 root media - -"
    "d /mnt/media/Media/Music 2775 root media - -"
    "d /mnt/media/Media/TV\\x20Shows 2775 root media - -"
  ];

  # Media Management
  services = {
    jellyfin = {
      enable = true;
      group = "media";
    };

    navidrome = {
      enable = true;
      group = "media";
      settings = {
        MusicFolder = "/mnt/media/Media/Music";
      };
    };

    audiobookshelf = {
      enable = true;
      group = "media";
      port = 9123;
    };

    # Using for Book metadata for readarr
    calibre-server = {
      enable = true;
      group = "media";
      libraries = [ "/mnt/media/Media/Books" ];
      port = 7007;
      host = "localhost";
      settings = [
        "--trusted-ips=localhost"
      ];
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
        download-dir = "/mnt/media/Media/Downloads"; # Adjust as needed
        incomplete-dir = "/mnt/media/Media/Downloads/incomplete";
        incomplete-dir-enabled = true;
        umask = 2; # Group write permissions (so Sonarr/Radarr can move files)
        dht-enabled = true;
        encryption = 1; # Prefer encrypted peers
        anti-brute-force-enabled = true;
        anti-brute-force-threshold = 10;
        blocklist-enabled = true;
        blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";
        preallocation = 1;

        # Limit Seeding
        ratio-limit = 1.0;
        ratio-limit-enabled = true;
        idle-seeding-limit-enabled = true;
        idle-seeding-limit = 30;

        # Speed Limits
        speed-limit-up = 1280;
        speed-limit-up-enabled = true;
        speed-limit-down = 10240;
        speed-limit-down-enabled = true;
        download-queue-enabled = false;
        download-queue-size = 10;

        # Speed tweaks
        peer-limit-global = 200;
        peer-limit-per-torrent = 60;
        upload-slots-per-torrent = 8;

        # Download Schedule
        alt-speed-enabled = true; # Enable alternative speed limits
        alt-speed-down = 5120; # KB/s download during restricted hours
        alt-speed-up = 512; # KB/s upload during restricted hours
        alt-speed-time-enabled = true; # Enable scheduled speed limit
        alt-speed-time-begin = 480; # Start at 8:00 (8am), in minutes after midnight
        alt-speed-time-end = 1380; # End at 23:00 (11pm), in minutes after midnight
        alt-speed-time-day = 126; # Monday–Saturday only

        # VPN
        rpc-whitelist-enabled = true;
        rpc-whitelist = "192.168.15.5";
        rpc-authentication-required = false;
        rpc-bind-address = "192.168.15.1"; # Bind RPC/WebUI to VPN network namespace address
      };
    };
  };
  # Get the encrypted file
  sops.secrets."server-wg.conf" = {
    sopsFile = ../../secrets/server-wg.yaml;
    mode = "0400"; # Only root can read
  };

  # Define VPN network namespace
  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = config.sops.secrets."server-wg.conf".path;
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
          proxyPass = "http://localhost:8096";
          proxyWebsockets = true;
        };
        kTLS = true;
      };
      "music.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          proxyPass = "http://localhost:4533";
          proxyWebsockets = true;
        };
        kTLS = true;
      };
      "audiobooks.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          proxyPass = "http://localhost:9123";
          proxyWebsockets = true;
          extraConfig = ''
            # Prevent 413 Request Entity Too Large error
            # by increasing the maximum allowed size of the client request body
            # For example, set it to 10 GiB
            client_max_body_size                10240M;
          '';
        };
        kTLS = true;
      };
      "request.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          proxyPass = "http://localhost:5055";
          proxyWebsockets = true;
        };
        kTLS = true;
      };
      "prowlarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:9696";
        };
        kTLS = true;
      };
      "radarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:7878";
        };
        kTLS = true;
      };
      "readarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:8787";
        };
        kTLS = true;
      };
      "bazarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:6767";
        };
        kTLS = true;
      };
      "sonarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:8989";
        };
        kTLS = true;
      };
      "lidarr.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        locations."/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:8686";
        };
        kTLS = true;
      };
    };
  };

  # Backup media to workstation hard drive
  services.borgbackup.jobs.media = {
    user = "codyt";
    paths = "/mnt/media/Media";
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i /home/codyt/.ssh/id_ed25519";
    repo = "codyt@192.168.1.238:/mnt/backup/Media";
    compression = "lz4";
    startAt = "daily";
    exclude = [
      "/mnt/media/Media/Downloads"
      "*.nfo"
      "*.jpg"
      "*.png"
      "*.svg"
    ];
  };

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
      intel-media-sdk # QSV up to 11th gen
    ];
  };
}
