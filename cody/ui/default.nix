{ config, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hyprland.nix
    ./notifications.nix
    ./appLauncher.nix
    ./waybar.nix
  ];

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };
  };

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
  };

  home.pandoc.enable = true;

  home.packages =
    (with pkgs; [
      # list of stable packages go here
      grim
      slurp
      wl-clipboard
      hyprpicker
      rofi-wayland
      ripdrag
      playerctl
      libnotify
      lukesmithxyz-bible-kjv
      discord
    ])
    ++
    (with pkgs-unstable; [
      # list of unstable packages go here
      vscode
      spotube
      fabric-ai
      ferdium
    ]);

  # Clipboard history
  services.cliphist.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
