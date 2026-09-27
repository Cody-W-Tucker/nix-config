{
  mkNginxVhost,
  config,
  ...
}:

let
  port = 28981;
in
{
  sops.secrets."paperless-password" = { };

  services.paperless = {
    enable = true;
    inherit port;
    mediaDir = "/mnt/backup/documents";
    consumptionDirIsPublic = true;
    passwordFile = config.sops.secrets.paperless-password.path;
    settings = {
      PAPERLESS_ADMIN_USER = "codyt";
      PAPERLESS_TIKA_ENABLED = "true";
      PAPERLESS_TIKA_URL = "http://localhost:9998";
      # Look in consume subdirectories for docs
      PAPERLESS_CONSUMER_RECURSIVE = "true";
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "true";
      PAPERLESS_CONSUMER_POLLING = "1"; # Faster processing
      # Reveres proxy stuff to get tika to work
      PAPERLESS_URL = "https://paperless.homehub.tv";
      USE_X_FORWARD_HOST = "true";
      USE_X_FORWARD_PORT = "true";
    };
  };

  # mediaDir is the backup/documents ZFS dataset. Selected datasets are
  # snapshotted centrally in backups.nix; no second local copy is needed.

  services.nginx.virtualHosts = mkNginxVhost {
    host = "paperless.homehub.tv";
    inherit port;
    # These configuration options are required for WebSockets to work.
    # Without them Tika document conversion wouldn't work
    # The default value 1M might be a little too small.
    locationExtraConfig = ''
      client_max_body_size 100M;

      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";

      proxy_set_header X-Forwarded-Host $server_name;
      add_header Referrer-Policy "strict-origin-when-cross-origin";
    '';
  };

  nas.backups.sqlite = [
    {
      name = "paperless";
      source = "/var/lib/paperless/db.sqlite3";
    }
  ];

}
