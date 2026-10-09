{
  lib,
  pkgs,
  ...
}:

{
  # Newer Stylix walks `config.lib` while building target options, and nixvim's
  # exported lib attrset now recurses there during flake checks after input updates.
  # Keep nixvim's internal extended lib for module evaluation, but don't re-export
  # it onto Home Manager's `lib` option.
  lib.nixvim = lib.mkForce { };

  imports = [
    ./keymaps.nix
    ./plugins/gitsigns.nix
    ./plugins/lsp.nix
    ./plugins/none-ls.nix
    ./plugins/conform.nix
    ./plugins/cmp.nix
    ./plugins/99.nix
    ./plugins/lualine.nix
    ./plugins/telescope.nix
    ./plugins/treesitter.nix
    ./plugins/startup.nix
    ./plugins/ts-autotag.nix
    ./plugins/img-clip.nix
  ];

  programs.nixvim = {
    enable = true;
    nixpkgs.useGlobalPackages = true;
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
    # Remote SSH (e.g. `kitty +kitten ssh` from Beast to NAS): forward yanks
    # via OSC 52 so Kitty pastes into the local clipboard. Local sessions keep
    # the wl-copy provider configured above.
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
        # Uncomment to use with only markdown
        command = "setlocal spell spelllang=en_us";
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
      zig.enable = true;
      image.enable = true;
    };
    # Set the leader key to <Space>
    globals.mapleader = " ";
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
    extraPackages = with pkgs; [ zig ];
  };
}
