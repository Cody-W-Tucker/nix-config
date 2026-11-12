{ pkgs, ... }:
{
  programs.nixvim.plugins.treesitter = {
    enable = true;
    highlight = {
      enable = true;
    };
    grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      bash
      json
      toml
      yaml
      lua
      xml
    ];
  };
}
