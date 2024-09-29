{ config, nixvim, pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
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
        command = "Twilight";
      }
      {
        event = [ "BufEnter" ];
        pattern = [ "*.md" ];
        command = "setlocal spell spelllang=en_us";
      }
    ];
    plugins = {
      telescope.enable = true;
      treesitter.enable = true;
      lsp.enable = true;
      direnv.enable = true;
      twilight = {
        enable = true;
        settings.context = 1;
      };
      goyo = {
        enable = true;
      };
    };
    extraPlugins = with pkgs.vimPlugins; [
      vim-pencil
    ];
  };
}
