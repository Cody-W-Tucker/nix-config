{
  inputs,
  pkgs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;

  # Upstream desktop package — no wrapper needed; the remote gateway is the
  # authenticated dashboard at :9119 so the desktop app talks to it directly.
  hermesDesktopUpstream = inputs.hermes-agent.packages.${system}.desktop;

  # Icon from the upstream source for xdg desktop entry integration.
  hermesDesktopIcon = pkgs.runCommandLocal "hermes-agent-desktop-icon" { } ''
    mkdir -p "$out/share/icons/hicolor/512x512/apps"
    cp "${inputs.hermes-agent}/apps/desktop/assets/icon.png" "$out/share/icons/hicolor/512x512/apps/hermes-agent.png"
  '';
in
{
  imports = [
    ./programs.nix
    ./packages/scripts
    ./obsidian
    ./hyprland.nix
    ./rofi.nix
    ./waybar.nix
    ./pipewire.nix
    ./notifications.nix
    ./speech-to-text.nix
    ./xdg.nix
  ];

  home.sessionVariables = {
    TERMINAL = "kitty";
  };

  # Enable Stylix for theming
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

  # Keep these enabled without settings letting stylix manage
  dconf.enable = true;

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
  };

  home.packages = with pkgs; [
    inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
    hermesDesktopUpstream # Hermes Agent desktop app (upstream, no API key wrapper)
    hermesDesktopIcon # Icon for XDG desktop entry
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
    playerctl # MPRIS cli; also provides playerctld D-Bus activation
    twitch-tui # Read chats from terminal
    mousam # Weather CLI tool
    witr # CLI tool that shows why processes are running
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
