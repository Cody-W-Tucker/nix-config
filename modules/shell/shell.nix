{ den, ... }:
{
  den.aspects.shell = {
    nixos =
      { pkgs, ... }:
      {
        programs = {
          starship.enable = true;
          zsh = {
            enable = true;
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
        themed = config.lib ? stylix;
        inherit (config.lib.stylix) colors;
        glowStyle =
          if themed then
            (pkgs.formats.json { }).generate "glow-stylix.json" {
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
          else
            "dark";
        glowPreview = ''piper -- CLICOLOR_FORCE=1 glow -w=$w -s=${glowStyle} "$1"'';
        whatchangedKey = key: subcommand: desc: {
          on = [
            "<A-g>"
            key
          ];
          run = "plugin whatchanged${subcommand}";
          inherit desc;
        };
      in
      {
        xdg.configFile = lib.optionalAttrs themed { "glow/stylix.json".source = glowStyle; };

        home = {
          packages = with pkgs; [
            fastfetch
            fd
            glow
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
            package = pkgs.unstable.yazi;
            enableZshIntegration = true;
            shellWrapperName = "rr";
            plugins = {
              inherit (pkgs.unstable.yaziPlugins) git piper;
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
              (whatchangedKey "a" "" "Toggle git changes")
              (whatchangedKey "r" " refresh" "Refresh git changes")
              (whatchangedKey "v" " preview" "Toggle diff / file content")
              (whatchangedKey "s" " staged" "Show staged changes")
              (whatchangedKey "w" " unstaged" "Show unstaged changes")
            ];
            settings = {
              mgr.ratio = [
                1
                2
                5
              ];
              plugin = {
                prepend_previewers = [
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
                    run = glowPreview;
                  }
                  {
                    url = "*.markdown";
                    run = glowPreview;
                  }
                  {
                    mime = "text/*";
                    run = "vscode-git-gutter";
                  }
                ];
                prepend_fetchers =
                  map
                    (url: {
                      id = "git";
                      inherit url;
                      run = "git";
                      group = "git";
                    })
                    [
                      "*"
                      "*/"
                    ];
              };
            };
            initLua =
              (lib.optionalString themed ''
                th.git = th.git or {}
                th.git.modified = ui.Style():fg("#${colors.base0A}")
                th.git.added = ui.Style():fg("#${colors.base0B}")
                th.git.deleted = ui.Style():fg("#${colors.base08}")
                th.git.updated = ui.Style():fg("#${colors.base0D}")
                th.git.untracked = ui.Style():fg("#${colors.base0C}")
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
            colors = lib.mkIf themed {
              "fg+" = "#${colors.base0D}";
              "bg+" = "-1";
              "fg" = "#${colors.base05}";
              "bg" = "-1";
              "prompt" = "#${colors.base03}";
              "pointer" = "#${colors.base0D}";
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
              share = false;
            };
            setOptions = [
              "EXTENDED_HISTORY"
              "INC_APPEND_HISTORY"
              "HIST_IGNORE_ALL_DUPS"
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
