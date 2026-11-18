{ config, mkNginxVhost, ... }:

let
  inherit (config.codyos.site) domain;
in
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
          "${config.codyos.site.hosts.beast.tailscale}:8384" = { };
        };
      };
    };
    virtualHosts =
      mkNginxVhost {
        host = "beast-syncthing.${domain}";
        locations = {
          "/" = {
            proxyPass = "http://beast_syncthing/";
          };
        };
      }
      // mkNginxVhost {
        host = "nas-syncthing.${domain}";
        locations = {
          "/" = {
            proxyPass = "http://nas_syncthing/";
          };
        };
      };
  };
}
