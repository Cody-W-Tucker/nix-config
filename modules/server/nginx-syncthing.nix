{ ... }:

{
  services.nginx = {
    upstreams = {
      server_syncthing = {
        servers = {
          "127.0.0.1:8384" = { };
        };
      };
      # workstation_syncthing = {
      #   servers = {
      #     "workstation:8384" = { };
      #   };
      # };
      beast_syncthing = {
        servers = {
          "100.108.143.19:8384" = { };
        };
      };
      aiserver_syncthing = {
        servers = {
          "100.68.141.25:8384" = { };
        };
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
    # "workstation-syncthing.homehub.tv" = {
    #   forceSSL = true;
    #   useACMEHost = "homehub.tv";
    #   locations."/" = {
    #     proxyPass = "http://workstation_syncthing/";
    #   };
    #   kTLS = true;
    # };
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
