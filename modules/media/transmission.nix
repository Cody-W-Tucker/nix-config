{
  den.aspects.transmission.nixos =
    {
      pkgs,
      config,
      inputs,
      ...
    }:

    {
      systemd.services.transmission.vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };
      sops.secrets."server-wg.conf" = {
        sopsFile = inputs.nixos-secrets.paths.serverWireguardSopsFile;
        mode = "0400";
      };
      vpnNamespaces.wg = {
        enable = true;
        wireguardConfigFile = config.sops.secrets."server-wg.conf".path;
        allowedIngress = [ "192.168.0.0/24" ];
        allowedEgress = [ "192.168.15.5/32" ];
        portMappings = [
          {
            from = 9091;
            to = 9091;
          }
          {
            from = 9696;
            to = config.services.prowlarr.settings.server.port;
          }
          {
            from = 8989;
            to = config.services.sonarr.settings.server.port;
          }
          {
            from = 7878;
            to = config.services.radarr.settings.server.port;
          }
          {
            from = 8787;
            to = config.services.readarr.settings.server.port;
          }
          {
            from = 6767;
            to = config.services.bazarr.listenPort;
          }
          {
            from = 8686;
            to = config.services.lidarr.settings.server.port;
          }
        ];
        vpn.allowedTCPPorts = [ 60729 ];
        vpn.allowedUDPPorts = [ 60729 ];
      };

      systemd.services.transmission = {
        after = [
          "mnt-media.device"
          "mnt-media.mount"
        ];
        requires = [ "mnt-media.mount" ];
      };

      services.transmission = {
        enable = true;
        package = pkgs.transmission_4;
        group = "media";
        openRPCPort = true;
        settings = {
          download-dir = "/mnt/media/Downloads";
          incomplete-dir = "/mnt/media/Downloads/incomplete";
          incomplete-dir-enabled = true;
          umask = 2;
          dht-enabled = true;
          encryption = 1;
          anti-brute-force-enabled = true;
          anti-brute-force-threshold = 10;
          blocklist-enabled = true;
          blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";
          preallocation = 1;
          ratio-limit = 1.0;
          ratio-limit-enabled = true;
          idle-seeding-limit-enabled = true;
          idle-seeding-limit = 30;
          speed-limit-up = 0;
          speed-limit-up-enabled = true;
          speed-limit-down = 0;
          speed-limit-down-enabled = true;
          download-queue-enabled = false;
          download-queue-size = 10;

          alt-speed-enabled = true;
          alt-speed-down = 10240;
          alt-speed-up = 1280;
          alt-speed-time-enabled = true;
          alt-speed-time-begin = 480;
          alt-speed-time-end = 1380;
          alt-speed-time-day = 126;
          peer-limit-global = 200;
          peer-limit-per-torrent = 60;
          upload-slots-per-torrent = 8;
          rpc-whitelist-enabled = true;
          rpc-whitelist = "192.168.15.1,192.168.15.5";
          rpc-authentication-required = false;
          rpc-bind-address = "192.168.15.1";

          peer-port = 60729;
        };
      };
    };
}
