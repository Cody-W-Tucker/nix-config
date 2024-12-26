{ config, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hyprland.nix
    ./notifications.nix
    ./nixvim.nix
    ./appLauncher.nix
    ./waybar.nix
  ];

  home.packages =
    (with pkgs; [
      # list of stable packages go here
      grim
      slurp
      wl-clipboard
      hyprpicker
      rofi-wayland
      gh
      ripdrag
      playerctl
      libnotify
      lukesmithxyz-bible-kjv

    ])

    ++

    (with pkgs-unstable; [
      # list of unstable packages go here
      vscode
      spotube
      fabric-ai
    ]);

  # Clipboard history
  services.cliphist.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
