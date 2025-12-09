{ pkgs, ... }:

{
  imports = [
    ./startup.nix
    ./keymaps.nix
    ./plugins/lsp.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "mocha";
        transparent_background = true;
      };
    };
    clipboard = {
      # Use system clipboard
      register = "unnamedplus";
      providers.wl-copy.enable = true;
    };
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
    };
    autoCmd = [
      {
        event = [
          "BufReadPost"
          "BufWritePost"
          "FileType"
        ];
        pattern = [ "*.md" ];
        # Uncomment to use with only markdown
        command = "setlocal spell spelllang=en_us";
      }
    ];
    plugins = {
      csvview.enable = true;
      lazygit.enable = true;
      git-conflict.enable = true;
      gitsigns.enable = true;
      comment = {
        enable = true;
        settings.mappings = {
          basic = true;
        };
      };
      which-key.enable = true;
      rainbow-delimiters.enable = true;
      snacks.enable = true;
      lualine = {
        enable = true;
        settings = {
          sections = {
            "lualine_a" = [ "mode" ];
            "lualine_b" = [
              "branch"
              "diff"
              "diagnostics"
            ];
            "lualine_c" = [ "filename" ];
            "lualine_x" = [
              "encoding"
              "fileformat"
              "filetype"
            ];
            "lualine_y" = [ "progress" ];
            "lualine_z" = [ "location" ];
          };
        };
      };
      web-devicons.enable = true;
      telescope = {
        enable = true;
        keymaps = {
          "<leader>cd" = {
            action = "zoxide list";
            options.desc = "Change directory with Zoxide"; # Optional: for which-key integration
          };
        };
        extensions.zoxide = {
          enable = true;
        };
      };
      yazi.enable = true;
      treesitter = {
        enable = true;
        settings.indent.enable = true;
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          bash
          json
          nix
          python
          toml
          yaml
          javascript
          typescript
          html
          css
          lua
          xml
          astro
          tsx
        ];
      };
      none-ls = {
        enable = true;
        enableLspFormat = true;
        settings = {
          updateInInsert = false;
        };
        sources = {
          code_actions = {
            gitsigns.enable = true;
            statix.enable = true;
          };
          diagnostics = {
            statix.enable = true;
            yamllint.enable = true;
          };
          formatting = {
            nixfmt = {
              enable = true;
              package = pkgs.nixfmt-rfc-style;
            };
            black = {
              enable = true;
              settings = ''
                {
                  extra_args = { "--fast" },
                }
              '';
            };
            prettier = {
              enable = true;
              disableTsServerFormatter = true;
              settings = ''
                {
                  extra_args = { "--no-semi" },
                }
              '';
            };
            stylua.enable = true;
            yamlfmt = {
              enable = true;
            };
            hclfmt.enable = true;
          };
        };
      };
      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            timeoutMs = 500;
            lspFallback = true;
          };
          formatters_by_ft = {
            astro = [ "prettier" ];
            html = [
              [
                "prettierd"
                "prettier"
              ]
            ];
            css = [
              [
                "prettierd"
                "prettier"
              ]
            ];
            javascript = [
              [
                "prettierd"
                "prettier"
              ]
            ];
            javascriptreact = [
              [
                "prettierd"
                "prettier"
              ]
            ];
            typescript = [
              [
                "prettierd"
                "prettier"
              ]
            ];
            typescriptreact = [
              [
                "prettierd"
                "prettier"
              ]
            ];
            python = [ "black" ];
            nix = [ "nixfmt" ];
            markdown = [
              [
                "prettierd"
                "prettier"
              ]
            ];
            yaml = [
              "yamllint"
              "yamlfmt"
            ];
          };
        };
      };
      ts-autotag = {
        enable = true;
        # (enables close/rename for astro + common JSX/TSX; disables on html to avoid over-closing)
        settings = {
          opts = {
            enable_close = true;
            enable_rename = true;
            enable_close_on_slash = false;
          };
          per_filetype = {
            astro = {
              enable_close = true;
              enable_rename = true;
            };
            javascriptreact = {
              enable_close = true;
              enable_rename = true;
            };
            typescriptreact = {
              enable_close = true;
              enable_rename = true;
            };
            html = {
              enable_close = false; # Avoids issues in plain HTML files
            };
          };
        };
      };
      # Enable completion
      cmp = {
        enable = true;
        settings = {
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-d>" = "cmp.mapping.scroll_docs(-4)";
            "<C-e>" = "cmp.mapping.close()";
            "<C-f>" = "cmp.mapping.scroll_docs(4)";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
            "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
          };
          sources = [
            { name = "nvim_lsp"; }
            { name = "path"; }
            { name = "buffer"; }
          ];
        };
      };
      direnv.enable = true;
      twilight = {
        enable = true;
        settings.context = 1;
      };
      goyo = {
        enable = true;
      };
    };
    # Set the leader key to <Space>
    globals = {
      mapleader = " ";
    };
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
  };
}
