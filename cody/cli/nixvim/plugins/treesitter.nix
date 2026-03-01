{ pkgs, ... }:
{
  programs.nixvim.plugins.treesitter = {
    enable = true;
    settings = {
      indent = {
        enable = true;
      };
      highlight = {
        enable = true;
      };
    };
    grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      bash
      json
      python
      toml
      yaml
      javascript
      typescript
      html
      css
      lua
      xml
      astro
      tsx
      zig
    ];
  };
}
