{ config, pkgs, pkgs-unstable, inputs, lib, ... }:

{
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./nixvim.nix
  ];

  home.packages =
    (with pkgs; [
      # list of stable packages go here
      gh
    ])
    ++
    (with pkgs-unstable; [
      # list of unstable packages go here
    ]);

  # User specific terminal settings
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
    };
  };

  programs = {
    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      history.path = "${config.xdg.dataHome}/zsh/zsh_history";
      history.size = 10000;
      shellAliases = {
        ssh = "kitty +kitten ssh";
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
    bash = {
      historyFile = "${config.xdg.dataHome}/bash/bash_history";
    };
    direnv = {
      enable = true;
    };
    fzf = {
      enable = true;
    };
    kitty = {
      enable = true;
      settings = {
        shell_integration = "no-cursor";
        window_padding_width = "0 8";
        confirm_os_window_close = "0";
        wayland_titlebar_color = "system";
        cursor_shape = "block";
      };
    };
  };
}
