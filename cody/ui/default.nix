{ config, inputs, pkgs, pkgs-unstable, ... }:

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
      playerctl
      libnotify
      todoist #cli client
      todoist-electron
      slack
      nautilus
      # nix language server
      nixd
      timewarrior
      inputs.zen-browser.packages.${pkgs.system}.default
      kdenlive
      baobab # Gnome disk usage app
      gcalcli # Google Calendar CLI tool
      taskwarrior-tui
    ])
    ++
    (with pkgs-unstable; [
      # list of unstable packages go here
      spotube
      code-cursor
      vscode
      legcord
      codex
    ]);

  sops.secrets.OPENAI_API_KEY = { };

  # Securely export OpenAI API key to interactive Shell for Codex
  programs.zsh.initExtra = ''
    export OPENAI_API_KEY="$(cat ${config.sops.secrets.OPENAI_API_KEY.path})"
  '';

  # Obs for screenrecording
  programs.obs-studio = {
    enable = true;
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
    extraConfig = ''
      color.header           = color4
      color.footnote         = color8
      color.label            = color6

      color.overdue          = color1
      color.due              = color3
      color.active           = color2
      color.completed        = color8
      color.deleted          = color5
      color.recurring        = color13
      color.scheduled        = color11
      color.waiting          = color14

      color.pri.H            = color1
      color.pri.M            = color3
      color.pri.L            = color2

      color.tagged           = color10
      color.blocked          = color9
      color.blocking         = color12

      color=on
    '';
  };

  # Doc conversion
  programs.pandoc.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
