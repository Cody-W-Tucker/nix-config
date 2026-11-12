{ pkgs, ... }:

{
  imports = [ ./ts-autotag.nix ];

  programs.nixvim = {
    clipboard.providers.wl-copy.enable = true;
    extraPackages = with pkgs; [
      zig
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
        zig
      ];
      conform-nvim = {
        settings = {
          formatters_by_ft = {
            astro = [ "prettier" ];
            html.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
            css.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
            javascript.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
            javascriptreact.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
            typescript.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
            typescriptreact.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
            python = [ "black" ];
            markdown.__raw = ''{ "prettierd", "prettier", stop_after_first = true }'';
          };
        };
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
    };
  };
}
