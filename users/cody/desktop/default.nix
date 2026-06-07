{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ./programs.nix
    ./harness
    ./packages/scripts
    ./editor/nixvim
    ./obsidian
    ./hyprland.nix
    ./rofi.nix
    ./waybar.nix
    ./pipewire.nix
    ./notifications.nix
    ./speech-to-text.nix
    ./xdg.nix
    inputs.crm-cli.homeManagerModules.default
  ];

  home.sessionVariables = {
    TERMINAL = "kitty";
  };

  # Enable Stylix for theming
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

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

  home.packages = with pkgs; [
    # list of stable packages go here
    inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
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
    libnotify # Notification library
    todoist # cli client
    nautilus # File manager
    nixd # Nix daemon for development
    baobab # Gnome disk usage app
    gcalcli # Google Calendar CLI tool
    feishin # Desktop app music player
    wttrbar # Weather bar for Waybar
    vesktop # Discord client
    kdePackages.kpeople # Contact integration for KDE Connect SMS
    doxx # Cli tool to open docx
    playerctl # MPRIS cli; also provides playerctld D-Bus activation
  ];

  services = {
    tailscale-systray.enable = true;

    # Control media via cli and waybar. Let D-Bus activation start playerctld
    # on demand so it does not race with the package's own activation file.
    mpris-proxy.enable = true;

    kdeconnect = {
      # Connect phone to computer
      enable = true;
      indicator = true;
    };

    cliphist = {
      # Clipboard history
      enable = true;
      allowImages = true;
      systemdTargets = "graphical-session.target";
      extraOptions = [
        "-max-dedupe-search"
        "10"
        "-max-items"
        "50"
      ];
    };
  };
}
