{
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_HOST = "127.0.0.1";
      UPTIME_KUMA_PORT = "3002";
    };
  };

  services.nginx.virtualHosts."uptime.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    kTLS = true;
    locations."/" = {
      proxyPass = "http://localhost:3002";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
