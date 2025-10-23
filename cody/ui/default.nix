{
  inputs,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [
    ./hyprland.nix
    ./appLauncher.nix
    ./waybar.nix
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

  # Notifications client
  services.swaync = {
    enable = true;
  };

  # Bluetooth applet for Waybar
  services.blueman-applet.enable = true; # Bluetooth manager

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
      grim # Screenshot utility
      slurp # Selection tool for screenshots
      wl-clipboard # Clipboard utility for Wayland
      tesseract4 # OCR utility
      (pkgs.writeScriptBin "screenshot-ocr" ''
        #!/bin/sh
        imgname="/tmp/screenshot-ocr-$(date +%Y%m%d%H%M%S).png"
        txtname="/tmp/screenshot-ocr-$(date +%Y%m%d%H%M%S)"
        txtfname=$txtname.txt
        grim -g "$(slurp)" $imgname;
        tesseract $imgname $txtname;
        wl-copy -n < $txtfname
      '')
      hyprpicker # Color picker for Hyprland
      playerctl # Media player control utility
      libnotify # Notification library
      todoist # cli client
      todoist-electron # Electron client for Todoist
      nautilus # File manager
      nixd # Nix daemon for development
      timewarrior # Time tracking utility
      inputs.zen-browser.packages.${pkgs.system}.default # Zen browser
      baobab # Gnome disk usage app
      gcalcli # Google Calendar CLI tool
      taskwarrior-tui # TUI for Taskwarrior
      feishin # Desktop app music player
      wttrbar # Weather bar for Waybar
      chromium
      yaak
    ])
    ++ (with pkgs-unstable; [
      # list of unstable packages go here
      code-cursor
      vscode
      legcord
    ]);

  # Obs for screenrecording
  programs.obs-studio = {
    enable = true;
    package = (pkgs-unstable.obs-studio.override { cudaSupport = true; });
  };

  # Clipboard history
  services.cliphist = {
    enable = true;
    allowImages = true;
    systemdTargets = "graphical-session.target";
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

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;
}
