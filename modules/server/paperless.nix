{ config, ... }:
let
  port = 28981;
in
{
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
      PAPERLESS_CONSUMER_POLLING = "1"; # Faster processing
      # Reveres proxy stuff to get tika to work
      PAPERLESS_URL = "paperless.homehub.tv";
      USE_X_FORWARD_HOST = "true";
      USE_X_FORWARD_PORT = "true";
    };
  };

  # Enable scan button daemon and paperless-scanning.nix
  services.scanbd = {
    enable = true;
  };

  services.nginx = {
    virtualHosts."paperless.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
        # These configuration options are required for WebSockets to work.
        # Without them Tika document conversion wouldn't work

        # The default value 1M might be a little too small.
        extraConfig = ''
          client_max_body_size 10M;
        
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";

          proxy_redirect off;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Host $server_name;
          add_header Referrer-Policy "strict-origin-when-cross-origin";
        '';
      };
    };
  };
}

