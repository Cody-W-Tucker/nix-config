{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.home-assistant ];

  den.aspects.home-assistant.nixos =
    {
      config,
      lib,
      mkNginxVhost,
      pkgs,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.MusicAssistant = {
        group = "Consume";
        order = 30;
        card = {
          href = "https://music-assistant.${domain}";
          icon = "music-assistant";
          description = "Music Management";
        };
      };

      codyos.homepage.cards.HomeAssistant = {
        group = "Network";
        order = 40;
        card = {
          href = "https://home-assistant.${domain}";
          icon = "home-assistant";
          description = "Home Automation";
        };
      };

      services = {
        music-assistant = {
          enable = true;
          openFirewall = true;
          providers = [
            "alexa"
            "audible"
            "audiobookshelf"
            "builtin"
            "chromecast"
            "hass"
            "hass_players"
            "lastfm_scrobble"
            "listenbrainz_scrobble"
            "musicbrainz"
            "musiccast"
            "opensubsonic"
            "pandora"
            "roku_media_assistant"
            "sendspin"
            "sonos"
            "sonos_s1"
            "soundcloud"
            "spotify"
            "spotify_connect"
            "squeezelite"
            "subsonic_scrobble"
            "sync_group"
            "tunein"
            "ytmusic"
          ];
        };

        home-assistant = {
          enable = true;
          extraComponents = [
            "music_assistant"
            "zha"
            "androidtv_remote"
            "cast"
          ];
          package = pkgs.home-assistant.override {
            extraPackages = ps: [
              ps.aiohue
              ps."starlink-grpc-core"
              ps."ha-philipsjs"
              ps.androidtvremote2
              ps.pychromecast
              ps.pymetno
              ps.gtts
              ps."kegtron-ble"
              ps."ibeacon-ble"

              ps."jellyfin-apiclient-python"
              ps.aiopyarr
              ps."transmission-rpc"
              ps.aioimmich
              ps.adguardhome
              ps.aiosyncthing
              ps."python-overseerr"
              ps.tailscale

              ps.aiodhcpwatcher
              ps.aiodiscover
              ps."cached-ipaddress"
              ps."async-upnp-client"
              ps.aiousbwatcher
              ps.serialx
              ps.zeroconf

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
            default_config = { };
            automation = "!include automations.yaml";
            homeassistant = {
              name = "HomeHub";
              unit_system = "us_customary";
            };
            http = {
              use_x_forwarded_for = true;
              trusted_proxies = [ "127.0.0.1" ];
              server_host = "127.0.0.1";
            };
            mobile_app = { };
            prometheus = { };

            dhcp = { };
            ssdp = { };
            usb = { };
            zeroconf = { };
            bluetooth = { };
          };
        };

        nginx.virtualHosts = lib.mergeAttrsList (
          lib.mapAttrsToList
            (
              name: port:
              mkNginxVhost {
                host = "${name}.${domain}";
                inherit port;
                proxyWebsockets = true;
              }
            )
            {
              home-assistant = 8123;
              music-assistant = 8095;
            }
        );
      };

      nas.backups.sqlite = [
        {
          name = "home-assistant";
          source = "/var/lib/hass/home-assistant_v2.db";
        }
      ];
    };
}
