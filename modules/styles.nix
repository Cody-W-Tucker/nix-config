{ config, lib, pkgs, stylix, ... }:
{
  stylix = {
    enable = true;
    polarity = "dark";
    opacity = {
      applications = 0.9;
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
      noto-fonts-cjk-sans
      font-awesome
      source-han-sans
      (nerdfonts.override { fonts = [ "Meslo" ]; })
    ];
  };
}
