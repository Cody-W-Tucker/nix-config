{ config, pkgs, ... }:

{
  # Using Docker
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };


  imports = [
    ./photos.nix
  ];
}
