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
      group = "users";
      configDir = "/home/codyt/.config/syncthing";
      openDefaultPorts = true;
      overrideDevices = true;
      overrideFolders = true;
      guiAddress = "0.0.0.0:8384";
    };
  };
}
