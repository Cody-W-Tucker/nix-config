{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  imports = [
    ./perpelxia.nix
  ];
}
