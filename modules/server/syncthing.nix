{ config, ... }:

{
  services = {
    nginx.virtualHosts."backup.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8384/";
      };
    };
    syncthing = {
      enable = true;
      user = "codyt";
      openDefaultPorts = true;
      guiAddress = "0.0.0.0:8384";
      configDir = "/home/codyt/Backup/.config/syncthing";
    };
  };
}
