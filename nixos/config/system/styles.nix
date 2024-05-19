{ pkgs, config, ... }:

{
  stylix = {
    image = ./wallpaper.png;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tomorrow-night.yaml";

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
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
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans Mono";
      };

      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      font-awesome
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
