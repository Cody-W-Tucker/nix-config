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
    autoCmd = [
      {
        event = [ "BufEnter" ];
        pattern = [ "*.md" ];
        command = "PencilSoft";
      }
      {
        event = [ "BufEnter" ];
        pattern = [ "*.md" ];
        command = "Goyo";
      }
    ];
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
      vim-LanguageTool
      thesaurus_query-vim
      vim-wordy
      # writegood
    ];
  };
}
