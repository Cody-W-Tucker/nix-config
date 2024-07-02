{ config, ... }:

{
  services = {
    syncthing = {
      enable = true;
      user = "codyt";
      dataDir = "/mnt/backup"; # Default folder for new synced folders
      configDir = "/home/myusername/Documents/.config/syncthing"; # Folder for Syncthing's settings and keys
    };
  };
}
