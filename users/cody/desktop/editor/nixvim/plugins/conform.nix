{ pkgs, ... }:

{
  programs.nixvim.plugins = {
    conform-nvim = {
      enable = true;
      autoInstall = {
        enable = true;
        overrides = {
          black = pkgs.black;
        };
      };
      settings = {
        format_on_save = {
          timeout_ms = 500;
          lsp_format = "fallback";
        };
        formatters_by_ft = {
          astro = [ "prettier" ];
          html = [
            "prettierd"
            "prettier"
          ];
          css = [
            "prettierd"
            "prettier"
          ];
          javascript = [
            "prettierd"
            "prettier"
          ];
          javascriptreact = [
            "prettierd"
            "prettier"
          ];
          typescript = [
            "prettierd"
            "prettier"
          ];
          typescriptreact = [
            "prettierd"
            "prettier"
          ];
          python = [ "black" ];
          nix = [ "nixfmt" ];
          markdown = [
            "prettierd"
            "prettier"
          ];
          yaml = [
            "yamllint"
            "yamlfmt"
          ];
        };
        formatters = {
          prettierd = {
            stop_after_first = true;
          };
          prettier = {
            stop_after_first = true;
          };
        };
      };
    };
  };
}
