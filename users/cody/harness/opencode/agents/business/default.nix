{ pkgs, config, ... }:

let
  actualBudgetMcp = pkgs.writeShellApplication {
    name = "actual-budget-mcp";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      ACTUAL_PASSWORD="$(< ${config.sops.secrets.actual-budget-mcp-password.path})"
      export ACTUAL_PASSWORD
      ACTUAL_BUDGET_SYNC_ID="$(< ${config.sops.secrets.actual-budget-mcp-sync-id.path})"
      export ACTUAL_BUDGET_SYNC_ID

      unset DOCKER_HOST

      exec docker run \
        -i \
        --rm \
        -e ACTUAL_PASSWORD \
        -e ACTUAL_SERVER_URL="https://budget.homehub.tv" \
        -e ACTUAL_BUDGET_SYNC_ID \
        sstefanov/actual-mcp:v1.12.0 \
        --enable-write
    '';
  };
in
{
  imports = [
    ./skills/google-workspace
    ./skills/tasks
  ];

  sops.secrets = {
    "actual-budget-mcp-password" = { };
    "actual-budget-mcp-sync-id" = { };
  };

  programs.opencode.settings = {
    mcp.actualBudget = {
      type = "local";
      command = [ "${actualBudgetMcp}/bin/actual-budget-mcp" ];
      enabled = true;
    };

    tools."actualBudget_*" = false;
  };

  programs.opencode.agents.business = ''
    ---
    description: Business operations agent for accounting and Google Workspace workflows.
    tools:
      "actualBudget_*": true
    ---
    Business mode for accounting and Google Workspace tasks. Use the apprppriate mcp tools for your workflow. It is configured to use the actualBudget mcp tool for budget management and synchronization. Use the Google Workspace tools for managing your organization's Google Workspace tasks. 
  '';
}
