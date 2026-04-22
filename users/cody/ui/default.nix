{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ./obsidian
    ./hyprland.nix
    ./rofi.nix
    ./waybar.nix
    ./pipewire.nix
    ./notifications.nix
    ./speech-to-text.nix
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
    gtk4.theme = null; # Let Stylix handle GTK4 via CSS
  };

  home.packages = with pkgs; [
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
  ];

  services = {
    # Bluetooth manager systray
    blueman-applet.enable = true;
    tailscale-systray.enable = true;

    # Control media via cli and waybar
    playerctld.enable = true;
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

  programs = {
    chromium = {
      enable = true;
      # Chromecast improvement
      commandLineArgs = [ "--load-media-router-component-extension=1" ];
    };
    obs-studio = {
      # Obs for screenrecording
      enable = true;
    };
    firefox = {
      # Zen browser via Firefox module
      enable = true;
      # Replace firefox with zen browser to use home manager module
      package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
      profiles.default = {
        # hardware acceleration settings
        settings = {
          # Enable VA-API video decoding
          "media.ffmpeg.vaapi.enabled" = true;
          # Enable hardware decoding
          "media.hardware-video-decoding.enabled" = true;
          # Enable WebRender for better GPU acceleration
          "gfx.webrender.all" = true;
          "gfx.webrender.enabled" = true;
          # Additional video-path settings
          "media.ffmpeg.dmabuf-textures.enabled" = true;
          "media.rdd-ffmpeg.enabled" = true;
          # Disable software fallback for video decoding
          "media.decoder-doctor.notifications-allowed" = false;
        };
      };
    };
  };
}
