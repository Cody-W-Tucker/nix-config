{ config, pkgs, lib, ... }:

{
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
    zsh = {
      enable = true;
      history.path = "${config.xdg.dataHome}/zsh/zsh_history";
      syntaxHighlighting.enable = true;
      shellAliases = {
        ssh = "kitty +kitten ssh";
        ll = "ls -l";
        pullUpdate = "cd /etc/nixos && git pull && sudo nixos-rebuild switch";
        pullUpgrade = "cd /etc/nixos && git pull && sudo nix flake update /etc/nixos && sudo nixos-rebuild switch";
        update = ''
          cd /etc/nixos &&
          git add . &&
          git commit -m "Pre-update commit" &&
          sudo nixos-rebuild switch &&
          git push
        '';
        upgrade = ''
          cd /etc/nixos &&
          git add . &&
          git commit -m "Pre-upgrade commit" &&
          sudo nix flake update /etc/nixos &&
          sudo nixos-rebuild switch
        '';
        gcCleanup = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      };
      initExtra = ''
        eval "$(direnv hook zsh)"
      '';
      history.size = 10000;
    };
  };
}

