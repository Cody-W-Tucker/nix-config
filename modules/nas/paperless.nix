{
  pkgs,
  lib,
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
    # WORKAROUND (2026-10-04): paperless-ngx 2.20.15 flaky test
    # `test_error_skip_rule` fails during package build, so disable just that
    # test locally.
    # Upstream issue: https://github.com/paperless-ngx/paperless-ngx/issues/9921
    # REVIEW-BY: 2027-01-04 — drop `package` once nixpkgs paperless-ngx is no
    # longer 2.20.15 or the flaky test is fixed upstream.
    package = pkgs.paperless-ngx.overrideAttrs (oldAttrs: {
      disabledTests = oldAttrs.disabledTests ++ [ "test_error_skip_rule" ];
    });
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

  warnings = lib.optional
    (config.services.paperless.enable && pkgs.paperless-ngx.version != "2.20.15")
    "paperless-ngx is now ${pkgs.paperless-ngx.version}; remove the test_error_skip_rule disabledTests workaround if the flaky test is fixed.";

  nas.backups.sqlite = [
    {
      name = "paperless";
      source = "/var/lib/paperless/db.sqlite3";
    }
  ];

}
