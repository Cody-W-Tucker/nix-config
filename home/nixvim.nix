{ config, nixvim, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
    };
    plugins = {
      telescope.enable = true;
      treesitter.enable = true;
      lsp.enable = true;
      direnv.enable = true;
    };
  };
}
