{ config, pkgs, ... }:

{
  imports = [
    ./homeAssistant.nix
  ];

  # Enable Docker.
  virtualisation = {
    docker.enable = true;
    docker.autoPrune.enable = true;
    oci-containers = {
      backend = "docker";
    };
  };
}
