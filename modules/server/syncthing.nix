{ config, ... }:

{
  services = {
    nginx.virtualHosts."backup.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      http2 = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8384/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header        Host $host;
          proxy_set_header        X-Real-IP $remote_addr;
          proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header        X-Forwarded-Proto $scheme;
          proxy_read_timeout      600s;
          proxy_send_timeout      600s;
        '';
      };
    };
    syncthing = {
      enable = true;
      user = "codyt";
      openDefaultPorts = true;
      guiAddress = "127.0.0.1:8384";
      configDir = "/home/codyt/Backup/.config/syncthing";
    };
  };

}
