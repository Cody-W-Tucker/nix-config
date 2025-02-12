{ config, ... }:
let
  port = 28981;
in
{
  # Scansnap Scanner
  hardware.sane.enable = true;
  hardware.sane.drivers.scanSnap.enable = true;

  sops.secrets."paperless-password" = { };

  services.paperless = {
    enable = true;
    inherit port;
    mediaDir = "/mnt/hdd/Documents";
    consumptionDirIsPublic = true;
    passwordFile = config.sops.secrets.paperless-password.path;
    settings = {
      PAPERLESS_ADMIN_USER = "codyt";
      PAPERLESS_TIKA_ENABLED = "true";
      # Look in consume subdirectories for docs
      PAPERLESS_CONSUMER_RECURSIVE = "true";
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "true";
    };
  };

  services.nginx = {
    virtualHosts."paperless.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString port}";
        proxyWebsockets = true;
      };
    };
  };
}

