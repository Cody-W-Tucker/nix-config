{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./mako.nix
    ./nixvim.nix
    ./rofi.nix
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    # Add some packages to the user environment.
    grim
    slurp
    wl-clipboard
    hyprpicker
    mako
    swww
    rofi-wayland
    vscode
    gh
    ripdrag
    spotify
    blueman
  ];

  # Clipboard history
  services.cliphist.enable = true;
}
