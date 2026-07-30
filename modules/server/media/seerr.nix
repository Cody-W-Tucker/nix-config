{ mkMediaVhost, ... }:

{
  services.seerr.enable = true;

  services.nginx.virtualHosts = mkMediaVhost {
    host = "request.homehub.tv";
    port = 5055;
    recommendedProxySettings = true;
  };
}
