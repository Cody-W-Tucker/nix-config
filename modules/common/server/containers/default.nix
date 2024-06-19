{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
  };

  imports = [
    ./arm.nix
  ];
}
