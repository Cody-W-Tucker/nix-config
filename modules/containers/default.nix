{ config, pkgs, ... }:

{
  # Using Docker
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
    oci-containers.backend = "docker";
  };


  imports = [
    ./arm.nix
    ./actualBudget.nix
    ./collabora.nix
  ];
}
