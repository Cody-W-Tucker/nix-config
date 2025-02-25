{ config, ... }:

{
  services.adguardhome = {
    enable = true;
  };
  services.nginx.virtualHosts."adguardhome.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3000";
      proxyWebsockets = true;
    };
  };
}
