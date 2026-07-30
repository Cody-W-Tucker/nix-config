{
  # TV Series Manager
  services.sonarr = {
    enable = true;
    group = "media";
  };

  services.nginx.virtualHosts."sonarr.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://127.0.0.1:8989";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
