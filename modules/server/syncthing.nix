{ config, ... }:

{
  services = {
    nginx.virtualHosts."backup.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      http2 = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8384";
        proxyWebsockets = true; # Assuming you want WebSocket support for Syncthing as well
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
