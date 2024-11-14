{
  # Rss feed
  services.miniflux = {
    enable = true;
    config = {
      CLEANUP_FREQUENCY = 48;
      LISTEN_ADDR = "localhost:7777";
      CREATE_ADMIN = 0;
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
