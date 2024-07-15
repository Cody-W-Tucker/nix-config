{ config, pkgs, ... }:

{
  # Using Docker
  virtualisation = {
    docker.enable = true;
    oci-containers.backend = "docker";
  };


  imports = [
    ./arm.nix
  ];
}
