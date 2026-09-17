{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  crg = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.code-review-graph;
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

      exec npx --yes actual-mcp@1.14.0 --enable-write
    '';
  };
in
{
  config = {
    services.hermes-agent = {
      extraPackages = [ crg ];

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

      # nixos-option-search (utensils/mcp-nixos).
      mcpServers.nixos = {
        command = "${pkgs.nix}/bin/nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
        ];
      };

      # Official Stripe remote MCP (OAuth).
      mcpServers.stripe = {
        url = "https://mcp.stripe.com";
        auth = "oauth";
      };

      # Per-session stdio. ${workspaceFolder} is the
      # session cwd (TUI/CLI in a repo); gateway default is hermes/workspace.
      # HM mcpServers schema has no lazy / idle_timeout_seconds (YAML-only).
      mcpServers.code-review-graph = {
        command = lib.getExe crg;
        args = [
          "serve"
          "--repo"
          "\${workspaceFolder}"
        ];
        # llama-swap OpenAI embeddings (qwen3-embedding-0.6b).
        # nas:8081 so Tailscale clients resolve the same host.
        env.CRG_OPENAI_BASE_URL = "http://nas:8081/v1";
        env.CRG_OPENAI_API_KEY = "llama-swap";
        env.CRG_OPENAI_MODEL = "qwen3-embedding-0.6b";
        env.CRG_OPENAI_BATCH_SIZE = "16";
        env.CRG_ACCEPT_CLOUD_EMBEDDINGS = "1";
      };
    };
  };
}
