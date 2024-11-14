{ config, ... }:

{
  sops.secrets.miniflux-admin-password = { };

  # Rss feed
  services.miniflux = {
    enable = true;
    config = {
      CLEANUP_FREQUENCY = 48;
      LISTEN_ADDR = "localhost:7777";
      BASE_URL = "https://rss.homehub.tv";
      ADMIN_USERNAME = "admin";
      ADMIN_PASSWORD_FILE = config.sops.secrets.miniflux-admin-password.path;
    };
  };

  services.nginx.virtualHosts."rss.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:7777";
    };
  };
}
