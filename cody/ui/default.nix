{ inputs, pkgs, pkgs-unstable, ... }:

let 
obs-studio = pkgs-unstable.obs-studio;
in

{
  imports = [
    ./hyprland.nix
    ./notifications.nix
    ./appLauncher.nix
    ./waybar.nix
    ./mime.nix
    ./pipewire.nix
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
      tesseract4
      (pkgs.writeScriptBin "screenshot-ocr" ''
        #!/bin/sh
        imgname="/tmp/screenshot-ocr-$(date +%Y%m%d%H%M%S).png"
        txtname="/tmp/screenshot-ocr-$(date +%Y%m%d%H%M%S)"
        txtfname=$txtname.txt
        grim -g "$(slurp)" $imgname;
        tesseract $imgname $txtname;
        wl-copy -n < $txtfname
      '')
      hyprpicker
      ripdrag
      playerctl
      libnotify
      todoist #cli client
      todoist-electron
      slack
      gnome-calculator
      nautilus
      # nix language server
      nixd
      timewarrior
      inputs.zen-browser.packages.${pkgs.system}.default
      kdenlive
      unzip
      baobab # Gnome disk usage app
      gcalcli
    ])
    ++
    (with pkgs-unstable; [
      # list of unstable packages go here
      spotube
      zoom-us
      code-cursor
      vscode
      legcord
    ]);

  # Obs for screenrecording
  programs.obs-studio = {
    enable = true;
    package = obs-studio;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
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
