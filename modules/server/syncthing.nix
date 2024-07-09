{ config, ... }:

{
  services = {
    syncthing = {
      enable = true;
      user = "codyt";
      openDefaultPorts = true;
      guiAddress = "0.0.0.0:8384";
    };
  };
}
