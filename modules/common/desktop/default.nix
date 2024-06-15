{ pkgs, config, lib, ... }:{

  imports = [
    ./gpu.nix
    ./services.nix
  ];

}