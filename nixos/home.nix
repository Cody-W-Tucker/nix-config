{ config, pkgs, ... }:

{
  # Manage user environment with home-manager
  home-manager.users.codyt = { pkgs, ... }: {
    home.packages = with pkgs; [
      # Add some packages to the user environment.
      dconf
      grim
      slurp
      wl-clipboard
      hyprpicker
      starship
    ];
    imports = [ ./config/home ];
    dconf = {
      enable = true;
      settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
        };
      };
    };
    # X keyboard
    home.keyboard = {
      layout = "us";
      model = "pc104";
    };
    home.pointerCursor = {
      gtk.enable = true;
      # x11.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    gtk = {
      enable = true;
      iconTheme = {
        package = pkgs.gnome.adwaita-icon-theme;
        name = "Adwaita";
      };
      theme = {
        name = "WhiteSur-Dark-solid";
        package = pkgs.whitesur-gtk-theme;
      };
      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = 1;
      };
    };

    # Theme QT -> GTK
    qt = {
      enable = true;
      platformTheme = "gtk";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt;
      };
    };
    home.sessionVariables = {
      GTK_THEME = "WhiteSur-Dark";
      BROWSER = "google-chrome";
      EDITOR = "nvim";
      VISUAL = "code";
      TERMINAL = "kitty";
      LIBVA_DRIVER_NAME = "iHD";
      VDPAU_DRIVER = "va_gl";
      NIXOS_OZONE_WL = "1";
    };

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "23.11";
  };
}
