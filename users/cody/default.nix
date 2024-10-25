{ config, pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./notifications.nix
    ./nixvim.nix
    ./appLauncher.nix
    ./waybar.nix
  ];

  home.packages = with pkgs; [
    # Add some packages to the user environment.
    grim
    slurp
    wl-clipboard
    hyprpicker
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
