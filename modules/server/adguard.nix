{ config, ... }:

{
  services.adguardhome = {
    enable = true;
    port = 9999;
  };
  services.nginx.virtualHosts."adguardhome.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:9999";
      proxyWebsockets = true;
    };
  };
}
