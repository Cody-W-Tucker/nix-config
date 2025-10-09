{ pkgs, ... }:

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
        command = "setlocal spell spelllang=en_us";
      }
    ];
    plugins = {
      web-devicons.enable = true;
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
    # Set the leader key to <Space>
    globals = {
      mapleader = " ";
    };
    keymaps = [
      {
        mode = "n"; # Normal mode
        key = "<Leader>ff";
        action = "<cmd>Telescope find_files<CR>";
        options = { silent = true; };
      }
      {
        mode = "n";
        key = "<Leader>fg";
        action = "<cmd>Telescope live_grep<CR>";
        options = { silent = true; };
      }
      {
        mode = "n";
        key = "<Leader>fb";
        action = "<cmd>Telescope buffers<CR>";
        options = { silent = true; };
      }
      {
        mode = "n";
        key = "<Leader>fh";
        action = "<cmd>Telescope help_tags<CR>";
        options = { silent = true; };
      }
    ];
    extraPlugins = with pkgs.vimPlugins; [
      vim-pencil
    ];
  };
}
