{
  services.nginx.virtualHosts."search.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    kTLS = true;
    locations."/" = {
      proxyPass = "http://aiserver:4110";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 256m;
      '';
    };
  };
}
