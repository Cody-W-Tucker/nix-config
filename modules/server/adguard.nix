{ config, ... }:

{
  services.adguardhome = {
    enable = true;
  };
  services.nginx.virtualHosts."adguard.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
      proxyWebsockets = true;
    };
  };
}
