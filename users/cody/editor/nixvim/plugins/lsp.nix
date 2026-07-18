{ pkgs, inputs, ... }:

{
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
        copilot = {
          enable = true;
          package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}."copilot-language-server";
          onAttach.function = ''
            if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlineCompletion, bufnr) then
              vim.lsp.inline_completion.enable(true, { bufnr = bufnr })

              vim.keymap.set("i", "<C-l>", function()
                if vim.lsp.inline_completion.get({ bufnr = bufnr }) then
                  return ""
                end

                return "<C-l>"
              end, {
                desc = "LSP: accept inline completion",
                buffer = bufnr,
                expr = true,
                replace_keycodes = true,
              })
            end

            if not vim.g.copilot_signin_command_created then
              vim.g.copilot_signin_command_created = true

              vim.api.nvim_create_user_command("CopilotSignIn", function()
                local current_buf = vim.api.nvim_get_current_buf()
                local copilot_client = vim.lsp.get_clients({ bufnr = current_buf, name = "copilot" })[1]
                  or vim.lsp.get_clients({ name = "copilot" })[1]

                if not copilot_client then
                  vim.notify("[copilot] LSP client is not running", vim.log.levels.WARN)
                  return
                end

                copilot_client:request("signIn", vim.empty_dict(), function(err, res, ctx)
                  if err then
                    vim.notify("[copilot] failed to start sign-in: " .. vim.inspect(err), vim.log.levels.ERROR)
                    return
                  end

                  if not res then
                    vim.notify("[copilot] sign-in did not return a device flow", vim.log.levels.ERROR)
                    return
                  end

                  vim.fn.setreg("+", res.userCode)
                  vim.fn.setreg("*", res.userCode)
                  vim.notify(
                    "[copilot] code copied: " .. res.userCode .. " | open " .. res.verificationUri,
                    vim.log.levels.INFO
                  )

                  copilot_client:exec_cmd(res.command, { bufnr = ctx.bufnr or current_buf }, function(cmd_err, cmd_res)
                    if cmd_err then
                      vim.notify("[copilot] browser launch failed: " .. vim.inspect(cmd_err), vim.log.levels.WARN)
                      return
                    end

                    if cmd_res and cmd_res.status == "OK" then
                      vim.notify("[copilot] signed in as " .. cmd_res.user, vim.log.levels.INFO)
                    end
                  end)
                end, current_buf)
              end, { desc = "Start GitHub Copilot sign-in" })
            end
          '';
        };
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
