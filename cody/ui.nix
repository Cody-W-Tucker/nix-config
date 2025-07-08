{ pkgs, ... }:

{
  imports = [
    ./ui
    ./cli
  ];

  config = {
    # Keyboard
    home.keyboard = {
      layout = "us";
      model = "pc105";
    };

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

      image = ../modules/wallpapers/galaxy-waves.jpg;
    };

    home.sessionVariables.CUDA_CACHE_PATH = "\${HOME}/.cache/nv";

    # The state version is required and should stay at the version you originally installed.
    home.stateVersion = "24.05";
  };
}
