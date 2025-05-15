{ config, pkgs, inputs, ... }:

let
  rangerDevicons = pkgs.fetchFromGitHub {
    owner = "alexanderjeurissen";
    repo = "ranger_devicons";
    rev = "f227f212e14996fbb366f945ec3ecaf5dc5f44b0";
    sha256 = "sha256-ck53eG+mGIQ706sUnEHbJ6vY1/LYnRcpq94JXzwnGTQ="; 
  };
in

{
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./nixvim.nix
  ];

  home.packages =
    (with pkgs; [
      gh
      fd
      fastfetch
      unzip
      zip
    ]);

  home.sessionVariables = {
    VISUAL = "nvim";
    TERMINAL = "kitty";
  };

  # User specific terminal settings
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
    };
  };

  # Use esa instead of ls
  programs.eza = {
    enable = true;
    git = true;
    icons = "auto";
  };

  # Ranger file viewer
  programs.ranger = {
    enable = true;
    settings = {
      "preview_images" = true;
      "preview_images_method" = "kitty";
    };
    plugins = [
      "${rangerDevicons}"
    ];
  };

  programs = {
    # Remove default package installation prompt because it's not working
    command-not-found.enable = false;
    # Use fancier nix-index prompt instead TODO: Make nix-index work or switch (Bug causing out of memory.)
    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      history.path = "${config.xdg.dataHome}/zsh/zsh_history";
      history.size = 5000;
      shellAliases = {
        ssh = "kitty +kitten ssh";
        cd = "z";
        ll = "eza -l";
        ls = "eza";
        fo = "find-and-open-file";
        copy = "kitten clipboard";
        pullUpdate = "cd /etc/nixos && git pull && sudo nixos-rebuild switch";
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
      };
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
}
