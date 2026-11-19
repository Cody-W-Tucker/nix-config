{ den, ... }:
{
  # Shell feature, registered on every host and every user. The system half sets up zsh and
  # starship and the base command-line packages. The Home Manager half is the interactive
  # shell: zsh (vi-mode, history, aliases), the navigation tools wired into it (fzf, yazi,
  # eza, bat, zoxide, direnv) and the small CLI tools every host's user gets.
  # `config.lib ? stylix` is true only where the theming aspect imports Stylix (beast), so
  # fzf colors and the yazi git theme apply there and nowhere else.
  den.aspects.shell = {
    nixos =
      { pkgs, ... }:
      {
        programs = {
          starship = {
            enable = true;
          };
          zsh = {
            enable = true;
            # Disable the completion in the global module because it would call compinit
            # but the home manager config also calls compinit. This causes the cache to be invalidated
            # because the fpath changes in-between, causing constant re-evaluation and thus startup
            # times of 1-2 seconds. Disable the completion here and only keep the home-manager one to fix it.
            enableCompletion = false;
          };
        };

        environment.systemPackages = with pkgs; [
          btop
          wget
        ];
      };

    homeManager =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        home = {
          packages = with pkgs; [
            fastfetch
            fd
            tree
            unzip
            zip
          ];
          sessionVariables = {
            VISUAL = "nvim";
          };
        };

        programs = {
          ripgrep.enable = true;
          yazi = {
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
            initLua =
              (lib.optionalString (config.lib ? stylix) ''
                th.git = th.git or {}
                th.git.modified = ui.Style():fg("#${config.lib.stylix.colors.base0A}")
                th.git.added = ui.Style():fg("#${config.lib.stylix.colors.base0B}")
                th.git.deleted = ui.Style():fg("#${config.lib.stylix.colors.base08}")
                th.git.updated = ui.Style():fg("#${config.lib.stylix.colors.base0D}")
                th.git.untracked = ui.Style():fg("#${config.lib.stylix.colors.base0C}")
              '')
              + ''
                require("git"):setup()
              '';
          };
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
            colors = lib.mkIf (config.lib ? stylix) {
              "fg+" = "#" + config.lib.stylix.colors.base0D;
              "bg+" = "-1";
              "fg" = "#" + config.lib.stylix.colors.base05;
              "bg" = "-1";
              "prompt" = "#" + config.lib.stylix.colors.base03;
              "pointer" = "#" + config.lib.stylix.colors.base0D;
            };
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
          zoxide.enable = true;
          zsh = {
            enable = true;
            syntaxHighlighting.enable = true;
            autosuggestion.enable = true;
            enableCompletion = true;
            history = {
              path = "$HOME/.local/share/zsh/zsh_history";
              size = 10000;
              share = false; # Prevents concurrent sessions from stepping on each other
            };
            setOptions = [
              "EXTENDED_HISTORY" # Preserves timestamps and safely escapes multiline commands
              "INC_APPEND_HISTORY" # Writes to history immediately, not at session close
              "HIST_IGNORE_ALL_DUPS" # Cleans up duplicates to keep the file smaller
            ];
            plugins = [
              {
                name = "vi-mode";
                src = pkgs.zsh-vi-mode;
                file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
              }
            ];
            initContent = ''
              # Vim-style navigation for fzf: ctrl j/k move down/up instead of arrow keys
              export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --bind 'ctrl-j:down,ctrl-k:up'"

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
              cat = "bat";
              cd = "z";
              ll = "eza -l";
              ls = "eza";
            };
          };
        };
      };
  };

  den.default.includes = [ den.aspects.shell ];
}
