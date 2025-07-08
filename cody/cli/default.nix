{ config, pkgs, pkgs-unstable, lib, ... }:

{
  imports = [
    ./nixvim.nix
  ];

  config = {

    home.packages =
      (with pkgs; [
        gh
        fd
        fastfetch
        unzip
        zip
      ])
      ++
      (with pkgs-unstable; [
        # list of unstable packages go here
        gemini-cli
      ]);

    home.sessionVariables = {
      VISUAL = "nvim";
      TERMINAL = "kitty";
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

    # Use esa instead of ls
    programs.eza = {
      enable = true;
      git = true;
      icons = "auto";
    };

    # Yazi file viewer
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    sops.secrets.OPENAI_API_KEY = { };

    programs = {
      zsh = {
        enable = true;
        syntaxHighlighting.enable = true;
        autosuggestion.enable = true;
        enableCompletion = true;
        history.path = "${config.xdg.dataHome}/zsh/zsh_history";
        history.size = 10000;
        shellAliases = {
          ssh- = "kitty +kitten ssh";
          cat = "bat";
          cd = "z";
          ll = "eza -l";
          ls = "eza";
          fo = "find-and-open-file";
          rr = "yazi";
          copy = "kitten clipboard";
          pullUpdate = "cd /etc/nixos && git pull && sudo nixos-rebuild switch";
          upgrade = ''
            cd /etc/nixos &&
            sudo nix flake update
            sudo nixos-rebuild switch
          '';
          gcCleanup = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
        };
        # Securely export ai API key to interactive Shell for Codex and Gemini
        initContent = ''
          export OPENAI_API_KEY="$(cat ${config.sops.secrets.OPENAI_API_KEY.path})"
        '';
      };
      bash = {
        historyFile = "${config.xdg.dataHome}/bash/bash_history";
      };
      direnv = {
        enable = true;
      };
      fzf = {
        enable = true;
        defaultCommand = "fd --type f --exclude '.*'";
      };
      kitty = {
        enable = true;
        settings = {
          shell_integration = "no-cursor";
          window_padding_width = "0 8";
          confirm_os_window_close = "0";
          wayland_titlebar_color = "system";
          cursor_shape = "block";
          enable_audio_bell = "no";
          cursor_trail = 1;
          cursor_trail_start_threshold = 3;
          cursor_trail_decay = "0.1 0.4";
          tab_bar_style = "powerline";
        };
        extraConfig = lib.mkForce ''
          foreground #${config.lib.stylix.colors.base05}
          background #${config.lib.stylix.colors.base00}
          color0  #${config.lib.stylix.colors.base03}
          color1  #${config.lib.stylix.colors.base08}
          color2  #${config.lib.stylix.colors.base0B}
          color3  #${config.lib.stylix.colors.base09}
          color4  #${config.lib.stylix.colors.base0D}
          color5  #${config.lib.stylix.colors.base0E}
          color6  #${config.lib.stylix.colors.base0C}
          color7  #${config.lib.stylix.colors.base06}
          color8  #${config.lib.stylix.colors.base04}
          color9  #${config.lib.stylix.colors.base08}
          color10 #${config.lib.stylix.colors.base0B}
          color11 #${config.lib.stylix.colors.base0A}
          color12 #${config.lib.stylix.colors.base0C}
          color13 #${config.lib.stylix.colors.base0E}
          color14 #${config.lib.stylix.colors.base0C}
          color15 #${config.lib.stylix.colors.base07}
          color16 #${config.lib.stylix.colors.base00}
          color17 #${config.lib.stylix.colors.base0F}
          color18 #${config.lib.stylix.colors.base0B}
          color19 #${config.lib.stylix.colors.base09}
          color20 #${config.lib.stylix.colors.base0D}
          color21 #${config.lib.stylix.colors.base0E}
          color22 #${config.lib.stylix.colors.base0C}
          color23 #${config.lib.stylix.colors.base06}
          cursor  #${config.lib.stylix.colors.base07}
          cursor_text_color #${config.lib.stylix.colors.base00}
          selection_foreground #${config.lib.stylix.colors.base01}
          selection_background #${config.lib.stylix.colors.base0D}
          url_color #${config.lib.stylix.colors.base0C}
          active_border_color #${config.lib.stylix.colors.base04}
          inactive_border_color #${config.lib.stylix.colors.base00}
          bell_border_color #${config.lib.stylix.colors.base03}
          tab_bar_style fade
          tab_fade 1
          active_tab_foreground   #${config.lib.stylix.colors.base05}
          active_tab_background   #${config.lib.stylix.colors.base01}
          active_tab_font_style   bold
          inactive_tab_foreground #${config.lib.stylix.colors.base07}
          inactive_tab_background #${config.lib.stylix.colors.base00}
          inactive_tab_font_style normal
          tab_bar_background #${config.lib.stylix.colors.base00}
        '';
      };
      bat = {
        enable = true;
        config = {
          pager = "less -FR";
        };
        themes =
          let
            src = pkgs.fetchFromGitHub {
              owner = "catppuccin";
              repo = "bat";
              rev = "ba4d16880d63e656acced2b7d4e034e4a93f74b1";
              hash = "sha256-6WVKQErGdaqb++oaXnY3i6/GuH2FhTgK0v4TN4Y0Wbw=";
            };
          in
          {
            Catppuccin-mocha = {
              inherit src;
              file = "Catppuccin-mocha.tmTheme";
            };
            Catppuccin-latte = {
              inherit src;
              file = "Catppuccin-latte.tmTheme";
            };
          };
      };
      zoxide.enable = true;
      ripgrep.enable = true;
    };
  };
}
