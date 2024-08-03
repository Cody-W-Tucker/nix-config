{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./nixvim.nix
    ./rofi.nix
    ./waybar.nix
    ./xdg.nix
  ];
}
