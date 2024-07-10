{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./xdg.nix
    ./rofi.nix
    ./waybar.nix
    ./nixvim.nix
  ];
}
