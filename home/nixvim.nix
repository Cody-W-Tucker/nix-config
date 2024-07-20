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
      {
        event = [ "BufEnter" ];
        pattern = [ "*.md" ];
        command = "Limelight";
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
      vim-pencil
      goyo-vim
    ];
  };
}
