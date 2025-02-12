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
    passwordFile = config.sops.secrets.paperless-password.path;
    settings = {
      PAPERLESS_ADMIN_USER = "codyt";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
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

