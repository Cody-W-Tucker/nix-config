{
  lib,
  pkgs,
  ...
}:

{
  lib.nixvim = lib.mkForce { };

  imports = [
    ./_keymaps.nix
    ./_plugins/gitsigns.nix
    ./_plugins/lsp.nix
    ./_plugins/none-ls.nix
    ./_plugins/conform.nix
    ./_plugins/cmp.nix
    ./_plugins/99
    ./_plugins/lualine.nix
    ./_plugins/telescope.nix
    ./_plugins/treesitter.nix
    ./_plugins/startup.nix
    ./_plugins/img-clip.nix
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
    clipboard = {
      register = "unnamedplus";
    };
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
