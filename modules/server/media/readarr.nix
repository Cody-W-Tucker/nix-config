{
  # Book Manager
  services.readarr = {
    enable = true;
    group = "media";
  };

  services.nginx.virtualHosts."readarr.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://127.0.0.1:8787";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
