{ config, pkgs, lib, ... }:

{
  programs.starship = {
    enable = true;
    presets = [ "nerd-font-symbols" ];
    settings = {
      add_newline = true;
    };
  };

  # Enable the user's shells and development environment
  programs = {
    zsh = {
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
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
    };
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      defaultEditor = true;
    };
  };
}

