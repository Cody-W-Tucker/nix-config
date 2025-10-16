{ ... }:

{
  programs.nixvim.keymaps = [
    {
      mode = "n"; # Normal mode
      key = "<Leader>ff";
      action = "<cmd>Telescope find_files<CR>";
      options = {
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<Leader>fg";
      action = "<cmd>Telescope live_grep<CR>";
      options = {
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<Leader>fb";
      action = "<cmd>Telescope buffers<CR>";
      options = {
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<Leader>fh";
      action = "<cmd>Telescope help_tags<CR>";
      options = {
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<Leader>-";
      action = "<cmd>Yazi<CR>";
      options = {
        silent = true;
      };
    }
    {
      mode = "n";
      key = "<Leader>==";
      action = "<cmd>Yazi cwd<CR>";
      options = {
        silent = true;
      };
    }
  ];
}
