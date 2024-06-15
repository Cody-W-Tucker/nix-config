{ config, pkgs, lib, ... }:

{
  programs.kitty = {
    enable = true;
    settings = {
      shell_integration = "no-cursor";
      window_padding_width = "0 8";
      confirm_os_window_close = "0";
      wayland_titlebar_color = "system";
      cursor_shape = "block";
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
      active_tab_foreground   #${config.lib.stylix.colors.base04}
      active_tab_background   #${config.lib.stylix.colors.base00}
      active_tab_font_style   bold
      inactive_tab_foreground #${config.lib.stylix.colors.base07}
      inactive_tab_background #${config.lib.stylix.colors.base08}
      inactive_tab_font_style bold
      tab_bar_background #${config.lib.stylix.colors.base00}
    '';

  };
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = lib.concatStrings [
        "$hostname"
        "$directory"
        "$nix_shell"
        "$git_branch"
        "$package"
        "$python"
        "$nodejs"
        "$memory_usage"
        "$character"
      ];
      nix_shell = {
        symbol = " ";
        style = "bold yellow";
        format = "via [$symbol$name]($style) ";
      };
      git_branch = {
        symbol = " ";
        style = "bold green";
        format = "on [$symbol$branch]($style) ";
      };
      directory = {
        style = "bold cyan";
        format = "[$path]($style) ";
      };
      hostname = {
        style = "bold red";
        format = "[$hostname]($style) ";
      };
      memory_usage = {
        style = "bold blue";
        format = "[$symbol$ram]($style) ";
      };
      package = {
        symbol = "󰏗 ";
        style = "bold blue";
        format = "[$symbol$version]($style) ";
      };
      python = {
        symbol = " ";
        style = "bold yellow";
        format = "[$symbol$version]($style) ";
      };
      nodejs = {
        symbol = " ";
        style = "bold green";
        format = "[$symbol$version]($style) ";
      };
    };
  };

  # Enable the user's shells and development environment
  programs = {
    lf = {
      enable = true;
      settings = {
        preview = true;
        hidden = false;
        drawbox = false;
        icons = false;
        ignorecase = true;
      };
      commands = {
        dragon-out = ''%${pkgs.ripdrag}/bin/ripdrag -a -x "$fx"'';
        editor-open = ''$$EDITOR $f'';
        mkdir = ''
          ''${{
            printf "Directory Name: "
            read DIR
            mkdir $DIR
          }}
        '';
      };
      previewer = {
        keybinding = "i";
        source = pkgs.writeShellScript "pv.sh" ''
          file=$1
             w=$2
             h=$3
             x=$4
             y=$5
        
             if [[ "$( ${pkgs.file}/bin/file -Lb --mime-type "$file")" =~ ^image ]]; then
                 ${pkgs.kitty}/bin/kitty +kitten icat --silent --stdin no --transfer-mode file --place "''${w}x''${h}@''${x}x''${y}" "$file" < /dev/null > /dev/tty
                 exit 1
             fi
        
             ${pkgs.pistol}/bin/pistol "$file"
        '';
      };
      extraConfig =
        let
          cleaner = pkgs.writeShellScriptBin "clean.sh" ''
            ${pkgs.kitty}/bin/kitty +kitten icat --clear --stdin no --silent --transfer-mode file < /dev/null > /dev/tty
          '';
        in
        ''
          set cleaner ${cleaner}/bin/clean.sh
        '';
    };
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    bash = {
      enable = true;
      historyFile = "${config.xdg.dataHome}/bash/bash_history";
      bashrcExtra = ''
        eval "$(direnv hook bash)"
        eval "$(gh copilot alias -- bash)"
      '';
    };
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      autocd = true;
      history.path = "${config.xdg.dataHome}/zsh/zsh_history";
      syntaxHighlighting.enable = true;
      shellAliases = {
        ssh = "kitty +kitten ssh";
        ll = "ls -l";
        update = "sudo nixos-rebuild switch --flake /etc/nixos --option eval-cache false";
        upgrade = "nix flake update /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos --option eval-cache false";
        gcCleanup = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      };
      initExtra = ''
        eval "$(direnv hook zsh)"
        eval "$(gh copilot alias -- zsh)"
      '';
      history.size = 10000;
    };
  };
}

