{ mkNginxVhost, ... }:

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
    virtualHosts =
      mkNginxVhost {
        host = "beast-syncthing.homehub.tv";
        locations = {
          "/" = {
            proxyPass = "http://beast_syncthing/";
          };
        };
      }
      // mkNginxVhost {
        host = "nas-syncthing.homehub.tv";
        locations = {
          "/" = {
            proxyPass = "http://nas_syncthing/";
          };
        };
      };
  };
}
