{ config, pkgs, lib, ... }:

{
  programs.starship = {
    enable = true;
    presets = [ "nerd-font-symbols" ];
    settings = {
      add_newline = false;
    };
  };

  # Enable the user's shells and development environment
  programs = {
    zsh = {
      enable = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -l";
        copy = "kitten clipboard";
        pullUpdate = "cd /etc/nixos && git pull && sudo nixos-rebuild switch";
        update = ''
          cd /etc/nixos &&
          git add . &&
          git commit -m "Pre-update commit" &&
          sudo nixos-rebuild switch &&
          git push
        '';
        upgrade = ''
          cd /etc/nixos &&
          sudo nix flake update
          sudo nixos-rebuild switch
        '';
        gcCleanup = "nix-collect-garbage --delete-old && sudo nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      };
    };
  };
}

