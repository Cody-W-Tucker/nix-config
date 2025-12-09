{ pkgs, ... }:

{
  imports = [
    ./startup.nix
    ./keymaps.nix
    ./plugins/lsp.nix
    ./plugins/none-ls.nix
    ./plugins/conform.nix
    ./plugins/cmp.nix
    ./plugins/lualine.nix
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
      markdown-preview.enable = true;
      commentary.enable = true;
      which-key.enable = true;
      rainbow-delimiters.enable = true;
      snacks.enable = true;
      yazi.enable = true;
      web-devicons.enable = true;
      direnv.enable = true;
      goyo.enable = true;
      twilight.enable = true;
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
    };
    # Set the leader key to <Space>
    globals.mapleader = " ";
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
  };
}
