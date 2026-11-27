{
  den.aspects.shelfmark.nixos =
    {
      config,
      pkgs,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
      port = 8084;
    in
    {
      codyos.homepage.cards.Shelfmark = {
        group = "Manage";
        order = 40;
        card = {
          href = "https://shelfmark.${domain}";
          icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons@master/png/shelfmark.png";
          description = "Audiobook Search";
        };
      };

      users.users.shelfmark = {
        isSystemUser = true;
        group = "shelfmark";
        uid = 340;
        description = "Shelfmark book/audiobook downloader";
      };
      users.groups.shelfmark = { };

      systemd.tmpfiles.rules = [
        "d /var/lib/shelfmark 0750 shelfmark media - -"
      ];

      systemd.services.shelfmark-dirs = {
        description = "Create Shelfmark staging directory on the mounted media filesystem";
        after = [ "mnt-media.mount" ];
        requires = [ "mnt-media.mount" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = [
            "${pkgs.coreutils}/bin/mkdir -p /mnt/media/Downloads/Shelfmark"
            "${pkgs.coreutils}/bin/chown root:media /mnt/media/Downloads/Shelfmark"
            "${pkgs.coreutils}/bin/chmod 2775 /mnt/media/Downloads/Shelfmark"
          ];
        };
      };

      virtualisation.oci-containers.containers.shelfmark = {
        image = "ghcr.io/calibrain/shelfmark:v1.3.15@sha256:9602290324993c801b319d3166b202b96bd9039af2416f0916dae03a5bdca815";
        environment = {
          PUID = toString config.users.users.shelfmark.uid;
          PGID = toString config.users.groups.media.gid;

          CONFIG_DIR = "/config";
          FLASK_HOST = "0.0.0.0";
          FLASK_PORT = toString port;
          TZ = config.time.timeZone;

          UMASK = "002";

          SEARCH_MODE = "universal";

          INGEST_DIR = "/mnt/media/Downloads/Shelfmark";
          HARDLINK_TORRENTS = "false";
          TRANSMISSION_DOWNLOAD_DIR = "/mnt/media/Downloads/books";
          DESTINATION_AUDIOBOOK = "/audiobooks/Books";
          HARDLINK_TORRENTS_AUDIOBOOK = "false";
          FILE_ORGANIZATION_AUDIOBOOK = "organize";
          TEMPLATE_AUDIOBOOK_ORGANIZE = "{Author}/{Title}/{Title}";

          CALIBRE_WEB_URL = "https://books.${domain}";
          AUDIOBOOK_LIBRARY_URL = "https://audiobooks.${domain}";

          SESSION_COOKIE_SECURE = "true";
        };
        volumes = [
          "/var/lib/shelfmark:/config"
          "/mnt/media/Downloads:/mnt/media/Downloads"
          "/mnt/media/AudioBookShelf:/audiobooks"
        ];
        extraOptions = [ "--network=host" ];
      };

      systemd.services."${config.virtualisation.oci-containers.backend}-shelfmark" = {
        after = [
          "mnt-media.mount"
          "shelfmark-dirs.service"
        ];
        requires = [
          "mnt-media.mount"
          "shelfmark-dirs.service"
        ];
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "shelfmark.${domain}";
        inherit port;
        proxyWebsockets = true;
      };

    };
}
