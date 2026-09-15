{
  config,
  lib,
  pkgs,
  ...
}:

let
  actualBudgetMcp = pkgs.writeShellApplication {
    name = "actual-budget-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      ACTUAL_PASSWORD="$(cat ${config.sops.secrets."actual-budget-mcp-password".path})"
      export ACTUAL_PASSWORD
      ACTUAL_BUDGET_SYNC_ID="$(cat ${config.sops.secrets."actual-budget-mcp-sync-id".path})"
      export ACTUAL_BUDGET_SYNC_ID
      ACTUAL_SERVER_URL="https://budget.homehub.tv"
      export ACTUAL_SERVER_URL

      exec npx --yes actual-mcp@1.12.1 --enable-write
    '';
  };
in
{
  config = {
    services.hermes-agent = {
      mcpServers.karakeep = {
        command = lib.getExe' pkgs.nodejs "npx";
        args = [
          "-y"
          "@karakeep/mcp"
        ];
        env.KARAKEEP_API_ADDR = "http://127.0.0.1:3005";
        env.KARAKEEP_API_KEY = "\${KARAKEEP_API_KEY}";
      };

      mcpServers.actualBudget = {
        command = lib.getExe actualBudgetMcp;
      };

      # Same server OpenCode uses as nixos-option-search (utensils/mcp-nixos).
      # Packages, NixOS/HM/nix-darwin options. Lives in Nix so it survives
      # hermes-agent-setup config merges.
      mcpServers.nixos = {
        command = "${pkgs.nix}/bin/nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
        ];
      };

      # Official Stripe remote MCP (OAuth). After HM switch:
      #   hermes mcp login stripe
      # Tokens land in $HERMES_HOME/mcp-tokens/. Do not put API keys here.
      # stripe_api_write exists — leave it unconfigured until a restricted
      # live-mode grant is intentional. New chat after switch to see tools.
      mcpServers.stripe = {
        url = "https://mcp.stripe.com";
        auth = "oauth";
      };
    };
  };
}
