{
  nixvim.plugins = {
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nixd.enable = true; # Nix
        cssls.enable = true; # CSS
        tailwindcss.enable = true; # TailwindCSS
        html.enable = true; # HTML
        pyright.enable = true; # Python
        dockerls.enable = true; # Docker
        bashls.enable = true; # Bash
        markdown_oxide.enable = true; # markdown
        # Keep ts_ls disabled or limited for .astro files – it conflicts
        ts_ls = {
          enable = true;
          extraOptions = {
            # Prevent ts_ls from handling .astro files
            filetypes = [
              "javascript"
              "javascriptreact"
              "typescript"
              "typescriptreact"
            ];
          };
        };
        astro = {
          enable = true;
          # Critical: use project-local TypeScript (Astro requires this)
          settings = {
            typescript = {
              tsdk = "./node_modules/typescript/lib";
            };
          };
        };
      };
      keymaps = {
        silent = true;
        lspBuf = {
          gd = "definition";
          gD = "references";
          gt = "type_definition";
          gi = "implementation";
          K = "hover";
          re = "rename";
        };
        diagnostic = {
          "<leader>k" = "goto_prev";
          "<leader>j" = "goto_next";
        };
      };
    };
  };
}
