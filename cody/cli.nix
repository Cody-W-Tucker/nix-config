{ pkgs, ... }:

{
  imports = [
    ./cli
  ];

  config = {

    # Keyboard
    home.keyboard = {
      layout = "us";
      model = "pc105";
    };

    # Stylix configuration
    stylix = {
      enable = true;
      polarity = "dark";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
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
          package = pkgs.nerd-fonts.jetbrains-mono;
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
        nerd-fonts.meslo-lg
      ];
    };

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "24.05";
  };
}
