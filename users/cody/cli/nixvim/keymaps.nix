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
      key = "<Leader>gg";
      action = "<cmd>LazyGit<CR>";
      options = {
        silent = true;
        desc = "Open Lazygit";
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
    {
      mode = "v";
      key = "<Leader>9v";
      action.__raw = ''function() require("99").visual() end'';
      options = {
        silent = true;
        desc = "99 Visual";
      };
    }
    {
      mode = "n";
      key = "<Leader>9s";
      action.__raw = ''function() require("99").search() end'';
      options = {
        silent = true;
        desc = "99 Search";
      };
    }
    {
      mode = [
        "n"
        "v"
      ];
      key = "<Leader>9x";
      action.__raw = ''function() require("99").stop_all_requests() end'';
      options = {
        silent = true;
        desc = "99 Stop";
      };
    }
    {
      mode = "n";
      key = "<Leader>9m";
      action.__raw = ''function() require("99.extensions.telescope").select_model() end'';
      options = {
        silent = true;
        desc = "99 Model";
      };
    }
    {
      mode = "n";
      key = "<Leader>9p";
      action.__raw = ''function() require("99.extensions.telescope").select_provider() end'';
      options = {
        silent = true;
        desc = "99 Provider";
      };
    }
  ];
}
