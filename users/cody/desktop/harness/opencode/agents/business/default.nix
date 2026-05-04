{
  pkgs,
  config,
  ...
}:

let
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
  imports = [
    ./skills/google-workspace
    ./skills/crm
    ./skills/tasks
  ];

  sops.secrets.actual-budget-mcp-password = { };
  sops.secrets.actual-budget-mcp-sync-id = { };

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
    description: Business operations agent for CRM, accounting, and Google Workspace workflows.
    mode: primary
    tools:
      "actualBudget_*": true
    ---
    Business mode for accounting, CRM, and Google Workspace tasks.
  '';
}
