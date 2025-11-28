{ pkgs, ... }:

{
  imports = [
    ./startup.nix
    ./keymaps.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
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
      autoclose.enable = true;
      jupytext.enable = true;
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
        indent = true;
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
      lsp = {
        enable = true;
        inlayHints = true;
        servers = {
          nixd.enable = true; # Nix
          cssls.enable = true; # CSS
          tailwindcss.enable = true; # TailwindCSS
          html.enable = true; # HTML
          pyright.enable = true; # Python
          dockerls.enable = true; # Docker
          bashls.enable = true; # Bash
          markdown_oxide.enable = true; # markdown
          # Keep ts_ls disabled or limited for .astro files – it conflicts
          ts_ls = {
            enable = true;
            extraOptions = {
              # Prevent ts_ls from handling .astro files
              filetypes = [
                "javascript"
                "javascriptreact"
                "typescript"
                "typescriptreact"
              ];
            };
          };
          astro = {
            enable = true;
            # Critical: use project-local TypeScript (Astro requires this)
            settings = {
              typescript = {
                tsdk = "./node_modules/typescript/lib";
              };
            };
          };
        };
        keymaps = {
          silent = true;
          lspBuf = {
            gd = "definition";
            gD = "references";
            gt = "type_definition";
            gi = "implementation";
            K = "hover";
            re = "rename";
          };
          diagnostic = {
            "<leader>k" = "goto_prev";
            "<leader>j" = "goto_next";
          };
        };
      };
      conform-nvim = {
        enable = true;
        formattersByFt = {
          astro = [ "prettier" ];
          javascript = [ "prettier" ];
          typescript = [ "prettier" ];
          javascriptreact = [ "prettier" ];
          typescriptreact = [ "prettier" ];
        };
        formatters = {
          prettier = {
            prepend_args = [
              "--plugin-search-dir=."
            ]; # finds prettier-plugin-astro automatically
          };
        };
      };
      ts-autotag = {
        enable = true;
        # (enables close/rename for astro + common JSX/TSX; disables on html to avoid over-closing)
        extraOptions = {
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
      none-ls = {
        enable = true;
        enableLspFormat = false;
        sources.formatting = {
          nixfmt.enable = true;
          black.enable = true;
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
