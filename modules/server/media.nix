{
  pkgs,
  config,
  inputs,
  ...
}:
{
  # Folder structure
  systemd = {
    tmpfiles.rules = [
      # Base directory must be owned by root to avoid unsafe path transitions
      # when subdirectories are owned by different users
      "d /mnt/media 0755 root root - -"
      # Flat media category directories with setgid for group inheritance
      "d /mnt/media/AudioBookShelf 2775 root media - -"
      "d /mnt/media/Books 2775 root media - -"
      "d /mnt/media/Channels 2775 root media - -"
      "d /mnt/media/Downloads 2775 root media - -"
      "d /mnt/media/Downloads/incomplete 2775 root media - -"
      "d /mnt/media/Movies 2775 root media - -"
      "d /mnt/media/Music 2775 root media - -"
      "d /mnt/media/TV\\x20Shows 2775 root media - -"
    ];
    services.transmission.vpnConfinement = {
      # Add systemd service to VPN network namespace
      enable = true;
      vpnNamespace = "wg";
    };
  };

  # Media Management
  services = {
    transmission = {
      enable = true;
      package = pkgs.transmission_4;
      group = "media";
      openRPCPort = true; # Allows Sonarr/Radarr to connect
      openPeerPorts = false; # Does not open peer ports on the firewall
      settings = {
        download-dir = "/mnt/media/Downloads";
        incomplete-dir = "/mnt/media/Downloads/incomplete";
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

        # Speed Limits (overnight)
        speed-limit-up = 0;
        speed-limit-up-enabled = true;
        speed-limit-down = 0;
        speed-limit-down-enabled = true;
        download-queue-enabled = false;
        download-queue-size = 10;

        # Download Schedule (during the day)
        alt-speed-enabled = true; # Enable alternative speed limits
        alt-speed-down = 10240; # KB/s download during restricted hours
        alt-speed-up = 1280; # KB/s upload during restricted hours
        alt-speed-time-enabled = true; # Enable scheduled speed limit
        alt-speed-time-begin = 480; # Start at 8:00 (8am), in minutes after midnight
        alt-speed-time-end = 1380; # End at 23:00 (11pm), in minutes after midnight
        alt-speed-time-day = 126; # Monday–Saturday only

        # Speed tweaks
        peer-limit-global = 200;
        peer-limit-per-torrent = 60;
        upload-slots-per-torrent = 8;

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
    sopsFile = inputs.nixos-secrets.paths.serverWireguardSopsFile;
    mode = "0400"; # Only root can read
  };

  # Define VPN network namespace
  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = config.sops.secrets."server-wg.conf".path;
    accessibleFrom = [ "192.168.0.0/24" ];
    portMappings = [
      {
        from = 9091;
        to = 9091;
      }
    ];
    openVPNPorts = [
      {
        port = 60729;
        protocol = "both";
      }
    ];
  };
}
