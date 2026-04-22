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
      Unless otherwise stated, you are operating in a NixOS system.

      This is a minimal environment. Common language runtimes (python, node, etc.) are not globally available.

      Use `nix shell` only when a required tool or runtime is missing.

      Do NOT use `nix shell` for standard Unix utilities that are typically available (e.g., bash, coreutils, grep, sed, awk, git).

      Examples:
      - Python: nix shell nixpkgs#python3 --command python script.py
      - Node: nix shell nixpkgs#nodejs --command node script.js

      Do not assume system-wide installations of languages or external tools.

      If a command fails due to a missing tool, retry using `nix shell` with the appropriate package.
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
            bash = "allow";
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
