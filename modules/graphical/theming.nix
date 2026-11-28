{ inputs, ... }:
{
  den.aspects.graphical = {
    nixos =
      { pkgs, ... }:
      {
        fonts = {
          fontDir.enable = true;
          enableDefaultPackages = true;
          packages = with pkgs; [
            noto-fonts
            font-awesome
            nerd-fonts.meslo-lg
            nerd-fonts.jetbrains-mono
          ];
        };
      };

    provides.to-users.homeManager =
      { config, pkgs, ... }:
      {
        imports = [ inputs.stylix.homeModules.stylix ];
        programs.zsh.autosuggestion.highlight = "fg=#${config.lib.stylix.colors.base04}";
        dconf.settings."org/gnome/desktop/interface".color-scheme =
          if config.stylix.polarity == "dark" then "prefer-dark" else "default";

        gtk = {
          enable = true;
          iconTheme = {
            package = pkgs.adwaita-icon-theme;
            name = "Adwaita";
          };
        };

        stylix = {
          enable = true;
          base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
          overlays.enable = false;
          polarity = "dark";
          targets = {
            nixvim.enable = false;
            gnome.enable = false;
            kde.enable = false;
            waybar.enable = false;
            hyprlock.enable = false;
            fzf.enable = false;
            rofi.fonts.enable = false;
            firefox.profileNames = [ "default" ];
            zen-browser.profileNames = [ "Default Profile" ];
            kitty.fonts.override.size = 16;
          };
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
              package = pkgs.noto-fonts-color-emoji;
              name = "Noto Color Emoji";
            };
          };
          image = ../../wallpapers/galaxy-waves.jpg;
        };
      };
  };
}
