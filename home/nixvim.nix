{ config, nixvim, pkgs, ... }:

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
    extraPlugins = with pkgs.vimPlugins; [
      limelight-vim
      # vim-litecorrect
      vim-pencil
      vim-wordy
      goyo-vim
      # writegood
    ];
    # extraConfigLua = ''
    #   require('examplePlugin').setup({
    #     foo = "bar"
    #   })
    # '';
  };
}
