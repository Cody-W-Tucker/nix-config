{
  mkNginxVhost,
  ...
}:

{
  services.mealie = {
    enable = true;
    port = 9000;
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "mealie.homehub.tv";
    port = 9000;
  };
}
