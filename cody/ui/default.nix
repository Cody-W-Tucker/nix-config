{ inputs, pkgs, pkgs-unstable, ... }:

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
      kdePackages.kdenlive
      baobab # Gnome disk usage app
      gcalcli # Google Calendar CLI tool
      taskwarrior-tui
      feishin
      picard
    ])
    ++
    (with pkgs-unstable; [
      # list of unstable packages go here
      code-cursor
      vscode
      legcord
      codex
    ]);


  # Obs for screenrecording
  programs.obs-studio = {
    enable = true;
  };

  # Clipboard history
  services.cliphist = {
    enable = true;
    allowImages = true;
    systemdTargets = "wayland-session@Hyprland.target";
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
      color=on

      # Main task states
      color.active      = color2
      color.completed   = color8
      color.deleted     = color5
      color.overdue     = color1
      color.scheduled   = color11
      color.due         = color3
      color.due.today   = color9
      color.recurring   = color13

      # Relationships and tags
      color.blocked     = color9
      color.blocking    = color12
      color.tagged      = color10

      # Headers and footers (optional, but can help)
      color.header      = color4
      color.footnote    = color8
      color.label       = color6

      # Priorities (if you use them)
      color.pri.H       = color1
      color.pri.M       = color3
      color.pri.L       = color2
    '';
  };

  # Doc conversion
  programs.pandoc.enable = true;

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
