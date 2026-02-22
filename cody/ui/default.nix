{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ./hyprland.nix
    ./rofi.nix
    ./waybar.nix
    ./pipewire.nix
    ./notifications.nix
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

  # Bluetooth applet for Waybar
  services.blueman-applet.enable = true; # Bluetooth manager

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
    playerctl # Media player control utility
    libnotify # Notification library
    todoist # cli client
    nautilus # File manager
    nixd # Nix daemon for development
    baobab # Gnome disk usage app
    gcalcli # Google Calendar CLI tool
    feishin # Desktop app music player
    wttrbar # Weather bar for Waybar
    vesktop
  ];

  programs.chromium = {
    enable = true;
    commandLineArgs = [ "--load-media-router-component-extension=1" ];
  };

  # Obs for screenrecording
  programs.obs-studio = {
    enable = true;
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
      "50"
    ];
  };

  # Playerctl Daemon to control media players from Waybar
  services.playerctld.enable = true;
  services.mpris-proxy.enable = true;

  # Zen browser via Firefox module for hardware acceleration settings
  programs.firefox = {
    enable = true;
    package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
    profiles.default = {
      settings = {
        # Enable VA-API video decoding
        "media.ffmpeg.vaapi.enabled" = true;
        # Force enable VA-API (even if blacklisted)
        "media.ffmpeg.vaapi-force-enabled" = true;
        # Enable hardware decoding
        "media.hardware-video-decoding.enabled" = true;
        # Enable WebRender for better GPU acceleration
        "gfx.webrender.all" = true;
        "gfx.webrender.enabled" = true;
        # Enable DMA-BUF for Wayland
        "widget.dmabuf.force-enabled" = true;
        # Additional NVIDIA fixes
        "media.ffmpeg.dmabuf-textures.enabled" = true;
        "media.rdd-ffmpeg.enabled" = true;
        # Disable software fallback for video decoding
        "media.decoder-doctor.notifications-allowed" = false;
      };
    };
  };
}
