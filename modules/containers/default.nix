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
    ./actualBudget.nix
    ./collabora.nix
    ./arm.nix
    ./blogs.nix
    ./data.nix
  ];
}
