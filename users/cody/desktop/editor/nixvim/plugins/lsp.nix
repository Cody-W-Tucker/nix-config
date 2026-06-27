{ ... }:

{
  programs.nixvim.extraConfigLua = ''
    if vim.lsp.inline_completion then
      vim.lsp.inline_completion.enable(true)

      vim.keymap.set("i", "<C-l>", function()
        if vim.lsp.inline_completion.get() then
          return ""
        end

        return "<C-l>"
      end, {
        desc = "Accept inline completion",
        expr = true,
        replace_keycodes = true,
      })
    end
  '';

  programs.nixvim.plugins = {
    lsp = {
      enable = true;
      inlayHints = true;
      servers = {
        nixd = {
          enable = true;
          settings = {
            nixd = {
              nixpkgs = {
                expr = "import (builtins.getFlake (toString ./.)).inputs.nixpkgs-unstable { }";
              };
              formatting = {
                command = [ "nixfmt" ];
              };
              options = {
                nixos = {
                  expr = "let flake = builtins.getFlake (toString ./.); in flake.nixosConfigurations.beast.options";
                };
              };
            };
          };
        };
        cssls.enable = true; # CSS
        tailwindcss.enable = true; # TailwindCSS
        html.enable = true; # HTML
        pyright.enable = true; # Python
        dockerls.enable = true; # Docker
        bashls.enable = true; # Bash
        marksman.enable = true; # Markdown
        zls.enable = true; # Zig
        copilot.enable = true;
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
