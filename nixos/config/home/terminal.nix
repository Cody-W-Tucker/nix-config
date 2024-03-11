{ config, pkgs, lib, ... }:
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
    # extraConfig = ''
    # include ${config.home.homeDirectory}/.cache/wal/colors-kitty.conf
    # '';
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
  programs.bash = {
    enable = true;
    historyFile = "${config.xdg.dataHome}/bash/bash_history";
    bashrcExtra = ''
      eval "$(direnv hook bash)"
      export PATH=$HOME/.npm-global/bin:$PATH
    '';
  };
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    autocd = true;
    history.path = "${config.xdg.dataHome}/zsh/zsh_history";
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
    };
    initExtra = ''
      eval "$(direnv hook zsh)"
      export PATH=$HOME/.npm-global/bin:$PATH
    '';
    history.size = 10000;
  };
}