{ ... }:

{
  services.nginx = {
    resolver.addresses = [ "100.100.100.100" ]; # Tailscale DNS resolver
  };

  services.nginx.virtualHosts = {
    "server-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://server:8384/";
      };
      kTLS = true;
    };
    "workstation-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://workstation:8384/";
      };
      kTLS = true;
    };
    "beast-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://beast:8384/";
      };
      kTLS = true;
    };
    "aiserver-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://aiserver:8384/";
      };
      kTLS = true;
    };
  };
}
