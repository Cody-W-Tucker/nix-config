{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./commands/taskwarrior
    ../../packages/desloppify
    ./tools/rtk
    ./skills/obsidian
    ./skills/code-search
    ./skills/google-workspace
    ./skills/crm
  ];

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    context = ''
      Unless otherwise stated, you are operating in a nixos system.

      Use nix shell to access common packages if needed.
    '';
    tui.theme = lib.mkForce "system";
    settings = {
      autoupdate = false;
      default_agent = "build";
      agent = {
        build = {
          permission = {
            "actualBudget_*" = "deny";
            "karakeep_*" = "deny";
            "grafana_*" = "deny";
            skill = {
              "obsidian-*" = "deny";
              "gws-*" = "deny";
              "crm-*" = "deny";
            };
          };
        };

        plan = {
          description = "Knowledge work agent for notes, bookmarks, dashboards, and research.";
          permission = {
            edit = "deny";
            bash = "ask";
            "actualBudget_*" = "deny";
            "karakeep_*" = "allow";
            "grafana_*" = "allow";
            skill = {
              "obsidian-*" = "allow";
              qmd = "allow";
              "gws-*" = "deny";
              "crm-*" = "deny";
            };
          };
        };

        business = {
          mode = "primary";
          description = "Business operations agent for CRM, accounting, and Google Workspace workflows.";
          permission = {
            edit = "deny";
            bash = "ask";
            "actualBudget_*" = "allow";
            "karakeep_*" = "deny";
            "grafana_*" = "deny";
            skill = {
              "obsidian-*" = "deny";
              qmd = "deny";
              "gws-*" = "allow";
              "crm-*" = "allow";
            };
          };
        };
      };
      lsp = {
        nix = {
          command = [ "${lib.getExe pkgs.nil}" ];
          extensions = [ ".nix" ];
          # 'initialization' passes options directly to the LSP during startup
          initialization = {
            formatting = {
              command = [ "${lib.getExe pkgs.nixfmt}" ];
            };
          };
        };
      };
      provider = {
        llama-swap = {
          npm = "@ai-sdk/openai-compatible";
          name = "llama-swap (aiserver)";
          options.baseURL = "http://aiserver:8080/v1";
          models = {
            "qwen3.5-35b" = {
              name = "Qwen3.5";
            };
          };
        };
      };
    };
  };
}
