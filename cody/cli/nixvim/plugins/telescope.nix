{
  programs.nixvim.telescope = {
    enable = true;
    keymaps = {
      "<leader>cd" = {
        action = "zoxide list";
        options.desc = "Change directory with Zoxide"; # Optional: for which-key integration
      };
    };
    extensions.zoxide = {
      enable = true;
    };
  };

}
