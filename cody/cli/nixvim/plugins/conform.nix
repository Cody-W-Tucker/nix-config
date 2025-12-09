{
  programs.nixvim.plugins = {
    conform-nvim = {
      enable = true;
      settings = {
        format_on_save = {
          timeoutMs = 500;
          lspFallback = true;
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
