{
  # Movie Manager
  services.radarr = {
    enable = true;
    group = "media";
  };

  services.nginx.virtualHosts."radarr.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://127.0.0.1:7878";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
