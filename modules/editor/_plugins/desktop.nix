{ lib, pkgs, ... }:
let
  prettierFirst.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
  closeAndRename = {
    enable_close = true;
    enable_rename = true;
  };
in
{
  programs.nixvim = {
    clipboard.providers.wl-copy.enable = true;
    extraPackages = with pkgs; [
      black
      prettier
      prettierd
    ];
    plugins = {
      zig.enable = true;
      lsp.servers = {
        cssls.enable = true;
        tailwindcss.enable = true;
        html.enable = true;
        pyright.enable = true;
        zls.enable = true;
        ts_ls = {
          enable = true;
          extraOptions.filetypes = [
            "javascript"
            "javascriptreact"
            "typescript"
            "typescriptreact"
          ];
        };
        astro.enable = true;
      };
      treesitter.grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        python
        javascript
        typescript
        html
        css
        astro
        tsx
      ];
      conform-nvim.settings.formatters_by_ft =
        lib.genAttrs [
          "html"
          "css"
          "javascript"
          "javascriptreact"
          "typescript"
          "typescriptreact"
          "markdown"
        ] (_: prettierFirst)
        // {
          astro = [ "prettier" ];
          python = [ "black" ];
        };
      none-ls.sources.formatting.prettier = {
        enable = true;
        disableTsServerFormatter = true;
        package = pkgs.prettier;
        settings = ''
          {
            extra_args = { "--no-semi" },
          }
        '';
      };
      ts-autotag = {
        enable = true;
        settings = {
          opts = closeAndRename // {
            enable_close_on_slash = false;
          };
          per_filetype =
            lib.genAttrs [
              "astro"
              "javascriptreact"
              "typescriptreact"
            ] (_: closeAndRename)
            // {
              html.enable_close = false;
            };
        };
      };
    };
  };
}
