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
    playerctl
  ];

  # Clipboard history
  services.cliphist.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
