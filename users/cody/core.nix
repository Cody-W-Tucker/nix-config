{ pkgs, ... }:

# Shared user config safe for all machines

{
  home = {
    # Keyboard
    keyboard = {
      layout = "us";
      model = "pc105";
    };
    packages = with pkgs; [
      fastfetch
      fd
      taskwarrior-tui
      timewarrior
      tree
      unzip
      zip
    ];
    sessionVariables = {
      VISUAL = "nvim";
    };
  };

  programs = {
    bash.historyFile = "$HOME/.local/share/bash/bash_history";

    bat = {
      enable = true;
      config.pager = "less -FR";
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    eza = {
      enable = true;
      git = true;
      icons = "auto";
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    git = {
      enable = true;
      ignores = [
        "tmp"
        ".nix-shell"
        ".direnv/"
        "__pycache__/"
      ];
      settings = {
        user = {
          name = "Cody W Tucker";
          email = "cody@tmvsocial.com";
        };
        alias.st = "status";
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        core.editor = "nvim";
        color = {
          ui = "auto";
          branch = "auto";
          diff = "auto";
          status = "auto";
        };
      };
    };

    lazygit = {
      enable = true;
      settings = {
        gui.paging = {
          colorArg = "always";
          paging = "delta --dark --paging=never";
        };
      };
    };
    ripgrep.enable = true;
    zoxide.enable = true;

    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
      history.path = "$HOME/.local/share/zsh/zsh_history";
      history.size = 10000;
      shellAliases = {
        cat = "bat";
        cd = "z";
        gg = "lazygit";
        ll = "eza -l";
        ls = "eza";
        op = "opencode";
        pullUpdate = "cd /etc/nixos && git pull && sudo nixos-rebuild switch";
        upgrade = ''
          cd /etc/nixos &&
          sudo nix flake update
          sudo nixos-rebuild switch
        '';
        gcCleanup = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo /run/current-system/bin/switch-to-configuration boot";
      };
    };
  };
}
