{
  services = {
    nginx.virtualHosts."backup.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://localhost:8384/";
      };
      kTLS = true;
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
