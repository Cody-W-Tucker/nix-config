{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./terminal.nix
    ./xdg.nix
    ./rofi.nix
    ./waybar.nix
    # ./browser.nix
  ];
}
