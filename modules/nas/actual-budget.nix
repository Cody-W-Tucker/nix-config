{
  mkNginxVhost,
  ...
}:

{
  services.nginx.virtualHosts = mkNginxVhost {
    host = "budget.homehub.tv";
    port = 5006;
    proxyWebsockets = true;
  };

  services.actual = {
    enable = true;
    settings.port = 5006;
    openFirewall = true;
    # settings.hostname = "budget.homehub.tv";
  };

}
