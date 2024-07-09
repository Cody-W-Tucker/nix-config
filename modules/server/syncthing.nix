{ config, ... }:

{
  services = {
    syncthing = {
      enable = true;
      user = "codyt";
      dataDir = "/mnt/hdd"; # Default folder for new synced folders
      openDefaultPorts = true;
      guiAddress = "0.0.0.0:8384";
    };
  };
}
