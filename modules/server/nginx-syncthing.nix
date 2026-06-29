{
  services.nginx = {
    upstreams = {
      server_syncthing = {
        servers = {
          "127.0.0.1:8384" = { };
        };
      };
      beast_syncthing = {
        servers = {
          "100.108.143.19:8384" = { };
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
    "beast-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://beast_syncthing/";
      };
      kTLS = true;
    };
  };
}
