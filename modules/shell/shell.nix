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
      let
        # glow has no Stylix target and ignores its own `glow.yml`, so the preview's
        # palette can only arrive as a style file on the command line. A style file
        # replaces glamour's built-in style rather than merging with it, so alongside the
        # Stylix colours this carries the few markers glamour would otherwise drop:
        # without them ordered lists lose their `1.`, bullets and task boxes disappear,
        # `---` renders as nothing and bold reads as plain text.
        themed = config.lib ? stylix;
        glowStyle =
          if themed then
            (pkgs.formats.json { }).generate "glow-stylix.json" (
              let
                inherit (config.lib.stylix) colors;
              in
              {
                document.color = "#${colors.base05}";
                heading = {
                  block_suffix = "\n";
                  bold = true;
                };
                h1.color = "#${colors.base08}";
                h2.color = "#${colors.base09}";
                h3.color = "#${colors.base0A}";
                h4.color = "#${colors.base0B}";
                h5.color = "#${colors.base0D}";
                h6.color = "#${colors.base0E}";
                strong.bold = true;
                emph.italic = true;
                strikethrough.crossed_out = true;
                item.block_prefix = "• ";
                enumeration.block_prefix = ". ";
                task = {
                  ticked = "[x] ";
                  unticked = "[ ] ";
                };
                block_quote = {
                  color = "#${colors.base03}";
                  indent = 1;
                  indent_token = "│ ";
                };
                hr = {
                  color = "#${colors.base03}";
                  format = "\n────────\n";
                };
                code.color = "#${colors.base0B}";
                link = {
                  color = "#${colors.base0D}";
                  underline = true;
                };
                link_text.color = "#${colors.base0C}";
                code_block.margin = 2;
              }
            )
          else
            "dark";
      in
      {
        xdg.configFile = lib.optionalAttrs themed { "glow/stylix.json".source = glowStyle; };

        home = {
          packages = with pkgs; [
            fastfetch
            fd
            glow # renders the markdown preview in yazi
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
            plugins = {
              git = pkgs.yaziPlugins.git;
              piper = pkgs.yaziPlugins.piper;
              # Neither is in nixpkgs.
              whatchanged = pkgs.fetchFromGitHub {
                owner = "WhoSowSee";
                repo = "whatchanged.yazi";
                rev = "52e3b31030a50b2f62a60ec43e5a7c496cdb424f";
                hash = "sha256-MDPqaqUzz4eqfdZKFHh75BhSMA1kiYK4lEm6CucuEsw=";
              };
              vscode-git-gutter =
                pkgs.fetchFromGitHub {
                  owner = "ShikherVerma";
                  repo = "yazi-plugins";
                  rev = "88bccaf7141362d8eec20df3531dd3caf06f8911";
                  hash = "sha256-PuywfE4D+l6MD8OL4B+2YQy+xGaCeCdxE6d0Xc9HVJc=";
                }
                + "/vscode-git-gutter.yazi";
            };
            keymap.mgr.prepend_keymap = [
              {
                on = [
                  "<A-g>"
                  "a"
                ];
                run = "plugin whatchanged";
                desc = "Toggle git changes";
              }
              {
                on = [
                  "<A-g>"
                  "r"
                ];
                run = "plugin whatchanged refresh";
                desc = "Refresh git changes";
              }
              {
                on = [
                  "<A-g>"
                  "v"
                ];
                run = "plugin whatchanged preview";
                desc = "Toggle diff / file content";
              }
              {
                on = [
                  "<A-g>"
                  "s"
                ];
                run = "plugin whatchanged staged";
                desc = "Show staged changes";
              }
              {
                on = [
                  "<A-g>"
                  "w"
                ];
                run = "plugin whatchanged unstaged";
                desc = "Show unstaged changes";
              }
            ];
            settings.mgr = {
              ratio = [
                1
                2
                5
              ];
            };
            # Render markdown in the preview pane instead of showing its source. This is
            # piper's documented glow recipe, with only `-s` changed to the Stylix style
            # above: piper pipes a command's output into the pane, passing the pane width
            # as `$w` and the hovered file as `$1`. Yazi uses the first matching previewer,
            # so whatchanged's view (a `search://` listing) comes first and markdown comes
            # before the gutter's catch-all `text/*`.
            settings.plugin.prepend_previewers = [
              {
                url = "search://*";
                run = "whatchanged";
              }
              {
                url = "search://*/";
                run = "whatchanged";
              }
              {
                url = "*.md";
                run = ''piper -- CLICOLOR_FORCE=1 glow -w=$w -s=${glowStyle} "$1"'';
              }
              {
                url = "*.markdown";
                run = ''piper -- CLICOLOR_FORCE=1 glow -w=$w -s=${glowStyle} "$1"'';
              }
              {
                mime = "text/*";
                run = "vscode-git-gutter";
              }
            ];
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
                require("whatchanged"):setup()
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
