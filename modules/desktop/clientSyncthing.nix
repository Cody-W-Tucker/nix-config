{ ... }:

{
  services = {
    syncthing = {
      enable = true;
      openDefaultPorts = true;
      overrideDevices = true;
      overrideFolders = true;
    };
  };
  networking.firewall.allowedTCPPorts = [ 8384 ];
}
