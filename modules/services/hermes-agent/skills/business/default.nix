{
  config,
  inputs,
  pkgs,
  ...
}:

let
  crmCli = inputs.crm-cli.packages.${pkgs.stdenv.hostPlatform.system}.crm-cli;
  googleWorkspaceCli = inputs.googleworkspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.gws;

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
    ./crm
    ./google-workspace
  ];

  sops.secrets = {
    "actual-budget-mcp-password" = {
      owner = config.services.hermes-agent.user;
      inherit (config.services.hermes-agent) group;
      mode = "0440";
    };
    "actual-budget-mcp-sync-id" = {
      owner = config.services.hermes-agent.user;
      inherit (config.services.hermes-agent) group;
      mode = "0440";
    };
  };

  users.users.${config.services.hermes-agent.user}.extraGroups = [ "docker" ];

  services.hermes-agent = {
    extraPackages = [
      crmCli
      googleWorkspaceCli
    ];
    mcpServers.actualBudget.command = "${actualBudgetMcp}/bin/actual-budget-mcp";
  };
}
