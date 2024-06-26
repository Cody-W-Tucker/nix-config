{ config, pkgs, ... }:

{
  # Using Docker
  virtualisation.docker = {
    enable = true;
  };


  # imports = [
  #   ./photos.nix
  # ];
}
