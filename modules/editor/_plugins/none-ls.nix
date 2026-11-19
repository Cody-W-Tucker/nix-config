{ pkgs, ... }:

{
  programs.nixvim.plugins = {
    none-ls = {
      enable = true;
      settings = {
        updateInInsert = false;
      };
      sources = {
        code_actions = {
          gitsigns.enable = true;
          statix.enable = true;
        };
        diagnostics = {
          statix.enable = true;
          yamllint.enable = true;
        };
        formatting = {
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
          stylua.enable = true;
          yamlfmt = {
            enable = true;
          };
          hclfmt.enable = true;
        };
      };
    };
  };
}
