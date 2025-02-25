{ config, ... }:

{
  networking.firewall.allowedUDPPorts = [ 53 ];
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    port = 8000;
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
