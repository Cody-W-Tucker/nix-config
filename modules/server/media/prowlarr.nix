{
  # Indexer Manager
  services.prowlarr = {
    enable = true;
  };

  services.nginx.virtualHosts."prowlarr.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://127.0.0.1:9696";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
