{ config, ... }:

{
  sops.secrets."miniflux/ADMIN_USERNAME" = {
    owner = "miniflux";
    group = "miniflux";
    mode = "0400";
  };
  sops.secrets."miniflux/ADMIN_PASSWORD" = {
    owner = "miniflux";
    group = "miniflux";
    mode = "0400";
  };

  sops.templates."miniflux-credentials".content = ''
    ADMIN_USERNAME=${config.sops.placeholder."miniflux/ADMIN_USERNAME"}
    ADMIN_PASSWORD=${config.sops.placeholder."miniflux/ADMIN_PASSWORD"}
  '';

  # Rss feed
  services.miniflux = {
    enable = true;
    config = {
      CLEANUP_FREQUENCY = 48;
      LISTEN_ADDR = "localhost:7777";
      BASE_URL = "https://rss.homehub.tv";
    };
    adminCredentialsFile = config.sops.templates."miniflux-credentials".path;
  };

  services.nginx.virtualHosts."rss.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:7777";
    };
  };
}
