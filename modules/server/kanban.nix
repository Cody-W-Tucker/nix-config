{ config, ... }:
let
  port = 8091;
in
{
  sops = {
    secrets = {
      kanban-secret-key-base = { };
      kanban-smtp-password = { };
      kanban-smtp-username = { };
    };
    templates = {
      "kanban.env" = {
        content = ''
          SECRET_KEY_BASE=${config.sops.placeholder."kanban-secret-key-base"}
          SMTP_USERNAME=${config.sops.placeholder."kanban-smtp-username"}
          SMTP_PASSWORD=${config.sops.placeholder."kanban-smtp-password"}
        '';
      };
    };
  };

  virtualisation.oci-containers.containers.kanban = {
    autoStart = true;
    image = "ghcr.io/basecamp/fizzy:main";
    environment = {
      TZ = "America/Chicago";
      BASE_URL = "https://kanban.homehub.tv";
      DISABLE_SSL = "true";
      SMTP_ADDRESS = "smtp.sendgrid.net";
      SMTP_PORT = "587";
      SMTP_AUTHENTICATION = "plain";
      SMTP_ENABLE_STARTTLS_AUTO = "true";
      MAILER_FROM_ADDRESS = "noreply@tmvsocial.com";
    };
    environmentFiles = [
      config.sops.templates."kanban.env".path
    ];
    ports = [
      "${toString port}:80"
    ];
    volumes = [
      "/var/lib/kanban:/rails/storage"
    ];
  };

  # Ensure the data directory exists with proper permissions
  # Fizzy container runs as rails user (UID 1000)
  systemd.tmpfiles.rules = [
    "d /var/lib/kanban 0755 1000 1000 -"
  ];

  services.nginx.virtualHosts."kanban.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:${toString port}";
      recommendedProxySettings = true;
      extraConfig = ''
        client_max_body_size 50M;
      '';
    };
    kTLS = true;
  };
}
