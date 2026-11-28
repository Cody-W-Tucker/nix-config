{ lib, pkgs, ... }:
{
  lib.nixvim = lib.mkForce { };

  imports = [
    ./_keymaps.nix
    ./_plugins/lsp.nix
    ./_plugins/99
    ./_plugins/startup.nix
  ];

  programs.nixvim = {
    enable = true;
    nixpkgs.useGlobalPackages = true;
    enableMan = false;
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
    clipboard.register = "unnamedplus";
    extraConfigLua = ''
      if vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil then
        local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
        if ok then
          vim.g.clipboard = {
            name = "OSC 52",
            copy = {
              ["+"] = osc52.copy("+"),
              ["*"] = osc52.copy("*"),
            },
            -- Reads follow Kitty's clipboard permission prompt.
            paste = {
              ["+"] = osc52.paste("+"),
              ["*"] = osc52.paste("*"),
            },
            cache_enabled = 0,
          }
        end
      end
    '';
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      wrap = false;
      showmode = false;
      tabstop = 2;
      scrolloff = 10;
      ignorecase = true;
      smartindent = true;
      autoindent = true;
      backup = false;
      swapfile = false;
      undofile = true;
      autowrite = false;
      updatetime = 300;
      timeoutlen = 500;
      ttimeoutlen = 0;
      autoread = true;
      hidden = true;
      backspace = "indent,eol,start";
      autochdir = false;
      selection = "inclusive";
    };
    autoCmd = [
      {
        event = [
          "BufReadPost"
          "BufWritePost"
          "FileType"
        ];
        pattern = [ "*.md" ];
        command = "setlocal spell spelllang=en_us";
      }
      {
        event = [ "FileType" ];
        pattern = [
          "markdown"
          "mkd"
        ];
        command = "SoftPencil";
      }
    ];
    plugins = {
      csvview.enable = true;
      nix.enable = true;
      lazygit.enable = true;
      markdown-preview.enable = true;
      render-markdown.enable = true;
      commentary.enable = true;
      which-key.enable = true;
      rainbow-delimiters.enable = true;
      snacks.enable = true;
      yazi.enable = true;
      web-devicons.enable = true;
      direnv.enable = true;
      trouble.enable = true;
      image.enable = true;
      treesitter = {
        enable = true;
        highlight.enable = true;
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          bash
          json
          toml
          yaml
          lua
          xml
        ];
      };
      telescope = {
        enable = true;
        keymaps."<leader>cd" = {
          action = "zoxide list";
          options.desc = "Change directory with Zoxide";
        };
        extensions.zoxide.enable = true;
      };
      gitsigns = {
        enable = true;
        settings = {
          current_line_blame = true;
          current_line_blame_opts = {
            virt_text = true;
            virt_text_pos = "eol";
          };
          signcolumn = true;
          signs = {
            add.text = "│";
            change.text = "│";
            changedelete.text = "~";
            delete.text = "_";
            topdelete.text = "‾";
            untracked.text = "┆";
          };
          watch_gitdir.follow_files = true;
        };
      };
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
          sources = map (name: { inherit name; }) [
            "nvim_lsp"
            "path"
            "buffer"
          ];
        };
      };
      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            timeout_ms = 500;
            lsp_format = "fallback";
          };
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            yaml = [
              "yamllint"
              "yamlfmt"
            ];
          };
        };
      };
      img-clip = {
        enable = true;
        settings = {
          default = {
            dir_path = "assets";
            file_name = "%y-%m-%d-%h-%m-%s";
            relative_to_current_file = false;
            template = "$file_path";
            use_absolute_path = false;
          };
          filetypes.markdown.download_images = true;
        };
      };
      lualine = {
        enable = true;
        settings.sections = {
          lualine_a = [ "mode" ];
          lualine_b = [
            "branch"
            "diff"
            "diagnostics"
          ];
          lualine_c = [ "filename" ];
          lualine_x = [
            "encoding"
            "fileformat"
            "filetype"
          ];
          lualine_y = [ "progress" ];
          lualine_z = [ "location" ];
        };
      };
      none-ls = {
        enable = true;
        settings.updateInInsert = false;
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
              package = pkgs.nixfmt;
            };
            stylua.enable = true;
            yamlfmt.enable = true;
            hclfmt.enable = true;
          };
        };
      };
    };
    globals.mapleader = " ";
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
    extraPackages = with pkgs; [
      nixfmt
      yamllint
      yamlfmt
    ];
  };
}
