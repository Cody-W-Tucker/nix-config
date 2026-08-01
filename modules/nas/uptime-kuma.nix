{
  mkNginxVhost,
  ...
}:

{
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_HOST = "127.0.0.1";
      UPTIME_KUMA_PORT = "3002";
    };
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "uptime.homehub.tv";
    port = 3002;
    proxyWebsockets = true;
  };
}
