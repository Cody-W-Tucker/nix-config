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

  # Backup documents to workstation hard drive
  services.borgbackup.jobs.documents = {
    user = "codyt";
    group = "documents";
    paths = "/mnt/hdd/Documents/documents/originals";
    encryption.mode = "none";
    environment.BORG_RSH = "ssh -i /home/codyt/.ssh/id_ed25519";
    repo = "codyt@192.168.1.238:/mnt/backup/Documents";
    compression = "lz4";
    startAt = "daily";
  };

  services.nginx = {
    virtualHosts."paperless.homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString port}";
        proxyWebsockets = true;
        # These configuration options are required for WebSockets to work.
        # Without them Tika document conversion wouldn't work

        # The default value 1M might be a little too small.
        extraConfig = ''
          client_max_body_size 100M;
        
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";

          proxy_redirect off;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Host $server_name;
          add_header Referrer-Policy "strict-origin-when-cross-origin";
        '';
      };
      kTLS = true;
    };
  };
}

