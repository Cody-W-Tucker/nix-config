{
  programs.nixvim.plugins.telescope = {
    enable = true;
    keymaps = {
      "<leader>cd" = {
        action = "zoxide list";
        options.desc = "Change directory with Zoxide";
      };
    };
    extensions.zoxide = {
      enable = true;
    };
  };
}
