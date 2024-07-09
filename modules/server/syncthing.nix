{ config, ... }:

{
  services = {
    syncthing = {
      enable = true;
      user = "codyt";
      group = "users";
      openDefaultPorts = true;
      guiAddress = "0.0.0.0:8384";
    };
  };
}
