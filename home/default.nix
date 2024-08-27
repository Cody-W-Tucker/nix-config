{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./mako.nix
    ./nixvim.nix
    ./rofi.nix
    ./waybar.nix
    ./xdg.nix
  ];

  # Clipboard history
  services.cliphist.enable = true;
}
