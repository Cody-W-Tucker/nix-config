{
  mkMediaVhost,
  config,
  ...
}:

{
  services.seerr.enable = true;

  services.nginx.virtualHosts = mkMediaVhost {
    host = "request.homehub.tv";
    port = config.services.seerr.settings.port;
  };
}
