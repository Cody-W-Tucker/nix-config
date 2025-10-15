{ pkgs, ... }:

{
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
      web-devicons.enable = true;
      telescope.enable = true;
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
            gd = {
              action = "definition";
              desc = "Goto Definition";
            };
            gr = {
              action = "references";
              desc = "Goto References";
            };
            gD = {
              action = "declaration";
              desc = "Goto Declaration";
            };
            gI = {
              action = "implementation";
              desc = "Goto Implementation";
            };
            gT = {
              action = "type_definition";
              desc = "Type Definition";
            };
            "<leader>cr" = {
              action = "rename";
              desc = "Rename";
            };
          };
        };
      };
      none-ls = {
        enable = true;
        sources.formatting = {
          nixfmt.enable = true;
          black.enable = true;
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
    keymaps = [
      {
        mode = "n"; # Normal mode
        key = "<Leader>ff";
        action = "<cmd>Telescope find_files<CR>";
        options = {
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<Leader>fg";
        action = "<cmd>Telescope live_grep<CR>";
        options = {
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<Leader>fb";
        action = "<cmd>Telescope buffers<CR>";
        options = {
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<Leader>fh";
        action = "<cmd>Telescope help_tags<CR>";
        options = {
          silent = true;
        };
      }
    ];
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
  };
}
