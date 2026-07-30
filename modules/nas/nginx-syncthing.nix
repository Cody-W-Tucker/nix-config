{
  services.nginx = {
    upstreams = {
      nas_syncthing = {
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
    "beast-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://beast_syncthing/";
      };
      kTLS = true;
    };
    "nas-syncthing.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://nas_syncthing/";
      };
      kTLS = true;
    };
  };
}
