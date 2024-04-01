{ config, pkgs, lib, ... }:

let
  palette = config.colorScheme.palette;
in
{
  programs.kitty = {
    enable = true;
    font = {
      name = "MesloLGSDZ Nerd Font Mono";
      size = 11;
    };
    settings = {
      shell_integration = "no-cursor";
      window_padding_width = "0 8";
      confirm_os_window_close = "0";
      background_opacity = ".8";
      wayland_titlebar_color = "system";
      cursor_shape = "block";
    };
    extraConfig = ''
      foreground #${palette.base05}
      background #${palette.base00}
      color0  #${palette.base03}
      color1  #${palette.base08}
      color2  #${palette.base0B}
      color3  #${palette.base09}
      color4  #${palette.base0D}
      color5  #${palette.base0E}
      color6  #${palette.base0C}
      color7  #${palette.base06}
      color8  #${palette.base04}
      color9  #${palette.base08}
      color10 #${palette.base0B}
      color11 #${palette.base0A}
      color12 #${palette.base0C}
      color13 #${palette.base0E}
      color14 #${palette.base0C}
      color15 #${palette.base07}
      color16 #${palette.base00}
      color17 #${palette.base0F}
      color18 #${palette.base0B}
      color19 #${palette.base09}
      color20 #${palette.base0D}
      color21 #${palette.base0E}
      color22 #${palette.base0C}
      color23 #${palette.base06}
      cursor  #${palette.base07}
      cursor_text_color #${palette.base00}
      selection_foreground #${palette.base01}
      selection_background #${palette.base0D}
      url_color #${palette.base0C}
      active_border_color #${palette.base04}
      inactive_border_color #${palette.base00}
      bell_border_color #${palette.base03}
      tab_bar_style fade
      tab_fade 1
      active_tab_foreground   #${palette.base04}
      active_tab_background   #${palette.base00}
      active_tab_font_style   bold
      inactive_tab_foreground #${palette.base07}
      inactive_tab_background #${palette.base08}
      inactive_tab_font_style bold
      tab_bar_background #${palette.base00}
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
    git = {
      enable = true;
      userEmail = "cody@tmvsocial.com";
      userName = "Cody-W-Tucker";
      lfs.enable = true;
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
        ll = "ls -l";
        update = "sudo nixos-rebuild switch --flake ~/Code/dotfiles/nixos --option eval-cache false";
        upgrade = "nix flake update ~/Code/dotfiles/nixos && sudo nixos-rebuild switch --flake ~/Code/dotfiles/nixos --option eval-cache false";
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
