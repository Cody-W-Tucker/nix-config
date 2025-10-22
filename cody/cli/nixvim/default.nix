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
        event = [ "BufEnter" ];
        pattern = [ "*.md" ];
        command = "setlocal spell spelllang=en_us";
      }
    ];
    plugins = {
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
        ];
      };
      lsp = {
        enable = true;
        inlayHints = true;
        servers = {
          nixd.enable = true; # Nix
          ts_ls.enable = true; # TS/JS
          cssls.enable = true; # CSS
          tailwindcss.enable = true; # TailwindCSS
          html.enable = true; # HTML
          astro.enable = true; # AstroJS
          pyright.enable = true; # Python
          dockerls.enable = true; # Docker
          bashls.enable = true; # Bash
          markdown_oxide.enable = true; # Markdown
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
      lsp-format.enable = true;
      none-ls = {
        enable = true;
        enableLspFormat = true;
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
