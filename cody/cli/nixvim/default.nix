{ pkgs, ... }:

{
  imports = [
    ./keymaps.nix
    ./plugins/lsp.nix
    ./plugins/none-ls.nix
    ./plugins/conform.nix
    ./plugins/cmp.nix
    ./plugins/lualine.nix
    ./plugins/telescope.nix
    ./plugins/treesitter.nix
    ./plugins/startup.nix
    ./plugins/ts-autotag.nix
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
      autoclose.enable = true;
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
      zig.enable = true;
    };
    # Set the leader key to <Space>
    globals.mapleader = " ";
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
    extraPackages = with pkgs; [ zig ];
  };
}
