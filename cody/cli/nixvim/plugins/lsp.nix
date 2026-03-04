{ pkgs, ... }:

let
  # Create a nixpkgs instance with allowUnfree to build copilot
  pkgsAllowUnfree = import pkgs.path {
    system = pkgs.system;
    config.allowUnfreePredicate = _: true;
  };
in

{
  programs.nixvim.plugins = {
    lsp-format.enable = true;
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nixd.enable = true; # Nix
        cssls.enable = true; # CSS
        copilot = {
          enable = true;
          package = pkgsAllowUnfree.copilot-language-server;
        };
        tailwindcss.enable = true; # TailwindCSS
        html.enable = true; # HTML
        pyright.enable = true; # Python
        dockerls.enable = true; # Docker
        bashls.enable = true; # Bash
        markdown_oxide.enable = true; # markdown
        zls.enable = true; # Zig
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
        astro.enable = true;
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
          ca = "code_action";
        };
        diagnostic = {
          "<leader>k" = "goto_prev";
          "<leader>j" = "goto_next";
        };
      };
    };
  };
}
