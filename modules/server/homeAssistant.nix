{ config, pkgs, ... }:

{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "esphome"
      "met"
      "radio_browser"
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = { };
      http = {
        server_host = "::1";
        trusted_proxies = [ "::1" ];
        use_x_forwarded_for = true;
      };
    };
  };
  services.nginx = {
    recommendedProxySettings = true;
    virtualHosts."home.homehub.tv" = {
      forceSSL = false;
      enableACME = false;
      extraConfig = ''
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = "http://[::1]:8123";
        proxyWebsockets = true;
      };
    };
  };
  networking.firewall.allowedTCPPorts = [ 8123 ];
}
