{ config, pkgs, ... }:

{
  imports = [
    ./intel-gpu.nix
    ./polkit.nix
    ./services.nix
  ];
}
