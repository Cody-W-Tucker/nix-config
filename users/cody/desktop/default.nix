{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.zen-browser.homeModules.beta
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

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };

  # Keep these enabled without settings letting stylix manage
  dconf.enable = true;

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
  };

  services = {
    tailscale-systray.enable = true;

    # Bluetooth AVRCP bridge for MPRIS media controls
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
