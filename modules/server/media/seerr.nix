{
  services.seerr = {
    enable = true;
  };

  services.nginx.virtualHosts."request.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      recommendedProxySettings = true;
      proxyPass = "http://127.0.0.1:5055";
      proxyWebsockets = true;
    };
    kTLS = true;
  };
}
