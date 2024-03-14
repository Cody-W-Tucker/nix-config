{ pkgs, config, inputs, gtkThemeFromScheme, ... }:
{
  home.packages = with pkgs; [
    # Add some packages to the user environment.
    dconf
    grim
    slurp
    wl-clipboard
    hyprpicker
    starship
  ];

  colorScheme = inputs.nix-colors.colorSchemes."google-dark";

  imports = [
    ./config/home
    inputs.nix-colors.homeManagerModules.default
    inputs.hyprland.homeManagerModules.default
    inputs.hypridle.homeManagerModules.default
  ];
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
      name = "${config.colorScheme.slug}";
      package = gtkThemeFromScheme { scheme = config.colorScheme; };
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
    BROWSER = "google-chrome";
    EDITOR = "nvim";
    VISUAL = "code";
    TERMINAL = "kitty";
    LIBVA_DRIVER_NAME = "iHD";
    VDPAU_DRIVER = "va_gl";
    NIXOS_OZONE_WL = "1";
  };
  services.hypridle = {
    enable = true;
    lockCmd = "pidof hyprlock || hyprlock";
    beforeSleepCmd = "loginctl lock-session";
    afterSleepCmd = "hyprctl dispatch dpms on";
    listeners = [
      {
        timeout = 900;
        onTimeout = "loginctl lock-session";
      }
      {
        timeout = 980;
        onTimeout = "hyprctl dispatch dpms off";
        onResume = "hyprctl dispatch dpms on";
      }
      {
        timeout = 1800;
        onTimeout = "systemctl suspend";
      }
    ];
  };

  # The state version is required and should stay at the version you originally installed.
  home.stateVersion = "23.11";
}
