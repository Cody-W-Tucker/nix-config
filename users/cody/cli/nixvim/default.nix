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
    # TODO: Remove once nixvim/home-manager resolve useGlobalPkgs + nixpkgs.config interaction
    # Currently triggers: "You have set either `nixpkgs.config` or `nixpkgs.overlays` while using `home-manager.useGlobalPkgs`"
    # Related issues:
    # - https://github.com/nix-community/nur/issues/877
    # - https://github.com/nix-community/home-manager/issues/3267
    # - https://github.com/nix-community/home-manager/pull/6172
    nixpkgs.config.allowUnfree = true;
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
      nix.enable = true;
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
      zig.enable = true;
      copilot-vim.enable = true;
    };
    # Set the leader key to <Space>
    globals.mapleader = " ";
    extraPlugins = with pkgs.vimPlugins; [ vim-pencil ];
    extraPackages = with pkgs; [ zig ];
  };
}
