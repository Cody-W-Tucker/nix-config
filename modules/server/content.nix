{ config, ... }:

{
  sops.secrets."miniflux/ADMIN_USERNAME" = { };
  sops.secrets."miniflux/ADMIN_PASSWORD" = { };

  sops.templates."miniflux-credentials".content = ''
    ADMIN_USERNAME=${config.sops.placeholder."miniflux/ADMIN_USERNAME"}
    ADMIN_PASSWORD=${config.sops.placeholder."miniflux/ADMIN_PASSWORD"}
  '';

  services = {
    # Miniflux RSS reader
    miniflux = {
      enable = true;
      config = {
        CLEANUP_FREQUENCY = 48;
        LISTEN_ADDR = "localhost:7777";
        BASE_URL = "https://rss.homehub.tv";
      };
      adminCredentialsFile = config.sops.templates."miniflux-credentials".path;
    };
    nginx.virtualHosts."rss.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://localhost:7777";
      };
      kTLS = true;
    };
  };
}
