{ config, pkgs-unstable, ... }:

{
  imports = [
    ./hyprland.nix
    ./notifications.nix
    ./nixvim.nix
    ./appLauncher.nix
    ./waybar.nix
  ];

  home.packages = with pkgs-unstable; [
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
    playerctl
    libnotify
    lukesmithxyz-bible-kjv
    fabric-ai
  ];

  # Clipboard history
  services.cliphist.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
