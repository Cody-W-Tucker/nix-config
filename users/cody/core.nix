{
  config,
  pkgs,
  lib,
  ...
}:

# Shared user config safe for all machines

{
  imports = [
    ./editor/nixvim
    ./harness
  ];
  home = {
    # Keyboard
    keyboard = {
      layout = "us";
      model = "pc105";
    };
    packages = with pkgs; [
      fastfetch
      fd
      ocrmypdf
      tree
      unzip
      zip
    ];
    sessionVariables = {
      VISUAL = "nvim";
    };
  };

  programs = {
    kitty = {
      enable = true;
      settings = {
        auto_reload_config = "-1";
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
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        decorations = {
          commit-decoration-style = "bold yellow box ul";
          file-decoration-style = "none";
          file-style = "bold yellow ul";
        };
        features = "decorations";
        whitespace-error-style = "22 reverse";
      };
    };
    yazi = {
      # Yazi file viewer
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "rr";
      plugins.git = pkgs.yaziPlugins.git;
      settings.plugin.prepend_fetchers = [
        {
          id = "git";
          url = "*";
          run = "git";
          group = "git";
        }
        {
          id = "git";
          url = "*/";
          run = "git";
          group = "git";
        }
      ];
      initLua = lib.optionalString (config.lib ? stylix) ''
        th.git = th.git or {}
        th.git.modified = ui.Style():fg("#${config.lib.stylix.colors.base0A}")
        th.git.added = ui.Style():fg("#${config.lib.stylix.colors.base0B}")
        th.git.deleted = ui.Style():fg("#${config.lib.stylix.colors.base08}")
        th.git.updated = ui.Style():fg("#${config.lib.stylix.colors.base0D}")
        th.git.untracked = ui.Style():fg("#${config.lib.stylix.colors.base0C}")

        require("git"):setup()
      '';
    };
    gh = {
      # Enable GitHub CLI
      enable = true;
    };
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
      colors = lib.mkIf (config.lib ? stylix) (
        lib.mkForce {
          "fg+" = "#" + config.lib.stylix.colors.base0D;
          "bg+" = "-1";
          "fg" = "#" + config.lib.stylix.colors.base05;
          "bg" = "-1";
          "prompt" = "#" + config.lib.stylix.colors.base03;
          "pointer" = "#" + config.lib.stylix.colors.base0D;
        }
      );
      defaultOptions = [
        "--margin=1"
        "--layout=reverse"
        "--border=none"
        "--info='hidden'"
        "--header=''"
        "--prompt='/ '"
        "-i"
        "--no-bold"
        "--preview='bat --style=numbers --color=always --line-range :500 {}'"
        "--preview-window=right:60%:wrap"
      ];
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
      plugins = [
        {
          name = "vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];
      initContent = ''
        # Fix fzf key bindings compatibility with zsh-vi-mode
        function zvm_after_init() {
          # Re-initialize fzf key bindings after zsh-vi-mode loads
          if command -v fzf-share >/dev/null; then
            source "$(fzf-share)/key-bindings.zsh"
            source "$(fzf-share)/completion.zsh"
          fi
        }
      '';
      shellAliases = {
        ssh- = "kitty +kitten ssh";
        copy = "kitten clipboard";
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
