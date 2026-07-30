{
  # Music Manager
  services.lidarr = {
    enable = true;
    group = "media";
  };

  services.nginx.virtualHosts."lidarr.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://127.0.0.1:8686";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
