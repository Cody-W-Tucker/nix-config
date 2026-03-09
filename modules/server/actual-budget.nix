{
  services.nginx.virtualHosts."budget.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:5006";
      proxyWebsockets = true;
    };
    kTLS = true;
  };

  services.actual = {
    enable = true;
    settings.port = 5006;
    openFirewall = true;
    # settings.hostname = "budget.homehub.tv";
  };

}
