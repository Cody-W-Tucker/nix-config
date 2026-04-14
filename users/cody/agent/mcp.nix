{ pkgs, config, ... }:
let
  grafanaMcp = pkgs.writeShellApplication {
    name = "grafana-mcp";
    text = ''
      export GRAFANA_URL="https://monitoring.homehub.tv"
      GRAFANA_SERVICE_ACCOUNT_TOKEN="$(< ${config.sops.secrets.grafana-mcp-token.path})"
      export GRAFANA_SERVICE_ACCOUNT_TOKEN

      exec ${pkgs.mcp-grafana}/bin/mcp-grafana "$@"
    '';
  };

  karakeepMcp = pkgs.writeShellApplication {
    name = "karakeep-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export KARAKEEP_API_ADDR="https://karakeep.homehub.tv"
      KARAKEEP_API_KEY="$(< ${config.sops.secrets.karakeep-api-key.path})"
      export KARAKEEP_API_KEY

      exec npx -y @karakeep/mcp "$@"
    '';
  };

  actualBudgetMcp = pkgs.writeShellApplication {
    name = "actual-budget-mcp";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      ACTUAL_PASSWORD="$(< ${config.sops.secrets.actual-budget-mcp-password.path})"
      export ACTUAL_PASSWORD
      ACTUAL_BUDGET_SYNC_ID="$(< ${config.sops.secrets.actual-budget-mcp-sync-id.path})"
      export ACTUAL_BUDGET_SYNC_ID

      exec docker run \
        -i \
        --rm \
        -e ACTUAL_PASSWORD \
        -e ACTUAL_SERVER_URL="https://budget.homehub.tv" \
        -e ACTUAL_BUDGET_SYNC_ID \
        sstefanov/actual-mcp:latest \
        --enable-write
    '';
  };
in
{
  sops.secrets.grafana-mcp-token = { };
  sops.secrets.karakeep-api-key = { };
  sops.secrets.actual-budget-mcp-password = { };
  # Actual: Settings -> Show advanced settings -> Sync ID
  sops.secrets.actual-budget-mcp-sync-id = { };

  programs.mcp = {
    enable = true;
    servers = {
      # docs-langchain = {
      #   url = "https://docs.langchain.com/mcp";
      # };
      context7 = {
        command = "nix-shell";
        args = [
          "-p"
          "nodejs"
          "--run"
          "npx -y @upstash/context7-mcp"
        ];
      };
      nixos-option-search = {
        command = "nix";
        args = [
          "run"
          "github:utensils/mcp-nixos"
        ];
      };
      grafana = {
        command = "${grafanaMcp}/bin/grafana-mcp";
      };
      karakeep = {
        command = "${karakeepMcp}/bin/karakeep-mcp";
      };
      actualBudget = {
        command = "${actualBudgetMcp}/bin/actual-budget-mcp";
      };
    };
  };
}
