{
  mkNginxVhost,
  config,
  ...
}:

{
  services.seerr.enable = true;

  services.nginx.virtualHosts = mkNginxVhost {
    host = "request.homehub.tv";
    port = config.services.seerr.port;
    proxyWebsockets = true;
  };
}
