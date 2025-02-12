{ config, ... }:
let
  paperless_port = 28981;
in
{
  sops.secrets."paperless-password" = { };

  services.paperless = {
    enable = true;
    inherit paperless_port;
    mediaDir = "/mnt/hdd/Documents";
    consumptionDirIsPublic = true;
    passwordFile = config.sops.secrets.paperless-password.path;
    settings = {
      PAPERLESS_ADMIN_USER = "codyt";
      PAPERLESS_TIKA_ENABLED = "true";
      # Look in consume subdirectories for docs
      PAPERLESS_CONSUMER_RECURSIVE = "true";
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = "true";
      PAPERLESS_CONSUMER_POLLING = "1"; # Faster processing
    };
  };

  services.nginx = {
    virtualHosts."paperless.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString paperless_port}";
        proxyWebsockets = true;
      };
    };
  };
}

