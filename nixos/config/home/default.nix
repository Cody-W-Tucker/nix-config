{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./terminal.nix
    ./xdg.nix
    ./rofi.nix
    ./waybar.nix
    # ./textEditors.nix
    # ./browser.nix
  ];
}
