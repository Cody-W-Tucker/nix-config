{ config, lib, pkgs, stylix, ... }:
{
  stylix = {
    image = config.lib.stylix.pixel "base0A";
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tomorrow-night.yaml";
    opacity = {
      applications = 1.0;
      terminal = 0.8;
      desktop = 1.0;
      popups = 1.0;
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    # Setting the fonts
    fonts = {
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };

      monospace = {
        package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
        name = "JetBrainsMono Nerd Font Mono";
      };

      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

  # Installing system wide fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      font-awesome
      otf-font-awesome
      source-han-sans
      (nerdfonts.override { fonts = [ "Meslo" ]; })
    ];
  };
}

#   fontconfig = {
#     defaultFonts = {
#       monospace = [ "Meslo LG M Regular Nerd Font Complete Mono" ];
#       serif = [ "Noto Serif" "Source Han Serif" ];
#       sansSerif = [ "Noto Sans" "Source Han Sans" ];
#     };
#   };
# };

# Base16 theme = tomorrow-night

# # Theme GTK
# gtk = {
#   enable = true;
#   iconTheme = {
#     package = pkgs.gnome.adwaita-icon-theme;
#     name = "Adwaita";
#   };
#   theme = {
#     name = "${config.colorScheme.slug}";
#     package = gtkThemeFromScheme { scheme = config.colorScheme; };
#   };
#   gtk3.extraConfig = {
#     gtk-application-prefer-dark-theme = 1;
#   };
#   gtk4.extraConfig = {
#     gtk-application-prefer-dark-theme = 1;
#   };
# };

# # Theme QT -> GTK
# qt = {
#   enable = true;
#   platformTheme.name = "gtk";
#   style = {
#     name = "adwaita-dark";
#     package = pkgs.adwaita-qt;
#   };
