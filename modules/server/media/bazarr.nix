{
  services.bazarr = {
    enable = true;
    group = "media";
  };

  services.nginx.virtualHosts."bazarr.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://127.0.0.1:6767";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
