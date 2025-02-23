{ config, pkgs, pkgs-unstable, ... }:

{
  imports = [
    ./hyprland.nix
    ./notifications.nix
    ./appLauncher.nix
    ./waybar.nix
    ./mime.nix
    ./xdg.nix
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
      discord
      todoist #cli client
      todoist-electron
      fabric-ai
      slack
      gnome-calculator
      nautilus
      libreoffice
      hunspell
    ])
    ++
    (with pkgs-unstable; [
      # list of unstable packages go here
      vscode
      code-cursor
      spotube
      ferdium
    ]);

  # Obs for screenrecording
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
    ];
  };


  # Clipboard history
  services.cliphist = {
    enable = true;
    allowImages = true;
    systemdTarget = "wayland-session@Hyprland.target";
    extraOptions = [
      "-max-dedupe-search"
      "10"
      "-max-items"
      "500"
    ];
  };

  programs.taskwarrior = {
    enable = true;
    package = pkgs.taskwarrior3;
  };

  # Doc conversion
  programs.pandoc.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
