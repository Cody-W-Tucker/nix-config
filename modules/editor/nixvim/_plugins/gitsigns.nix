{
  programs.nixvim.plugins.gitsigns = {
    enable = true;
    settings = {
      current_line_blame = true;
      current_line_blame_opts = {
        virt_text = true;
        virt_text_pos = "eol";
      };
      signcolumn = true;
      signs = {
        add = {
          text = "│";
        };
        change = {
          text = "│";
        };
        changedelete = {
          text = "~";
        };
        delete = {
          text = "_";
        };
        topdelete = {
          text = "‾";
        };
        untracked = {
          text = "┆";
        };
      };
      watch_gitdir = {
        follow_files = true;
      };
    };
  };
}
