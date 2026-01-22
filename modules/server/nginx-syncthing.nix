{ ... }:

{
  services.nginx = {
    upstreams = {
      server_syncthing = {
        servers = {
          "server:8384" = { };
        };
        extraConfig = "resolver 100.100.100.100;";
      };
      workstation_syncthing = {
        servers = {
          "workstation:8384" = { };
        };
        extraConfig = "resolver 100.100.100.100;";
      };
      beast_syncthing = {
        servers = {
          "beast:8384" = { };
        };
        extraConfig = "resolver 100.100.100.100;";
      };
      aiserver_syncthing = {
        servers = {
          "aiserver:8384" = { };
        };
        extraConfig = "resolver 100.100.100.100;";
      };
    };
  };

  services.nginx.virtualHosts = {
    "server-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://server_syncthing/";
      };
      kTLS = true;
    };
    "workstation-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://workstation_syncthing/";
      };
      kTLS = true;
    };
    "beast-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://beast_syncthing/";
      };
      kTLS = true;
    };
    "aiserver-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://aiserver_syncthing/";
      };
      kTLS = true;
    };
  };
}
