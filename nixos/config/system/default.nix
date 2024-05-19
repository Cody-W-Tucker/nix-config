{ config, pkgs, ... }:

{
  imports = [
    ./gpu.nix
    ./polkit.nix
    ./services.nix
    ./packages.nix
    ./styles.nix
  ];
}
