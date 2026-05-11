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

  taskSkill =
    builtins.replaceStrings
      [
        "# Task Agent"
        "Use This Tool For"
      ]
      [
        "# Task Skill"
        "Use This Skill For"
      ]
      (builtins.readFile inputs.cognitive-assistant.lib.operational.toolSpecs.tasks);
  googleWorkspaceSkill = name: "${inputs.googleworkspace-cli}/skills/${name}/SKILL.md";
  gmailTriageSkill = pkgs.writeText "gws-gmail-triage-SKILL.md" (
    builtins.replaceStrings
      [
        "description: \"Gmail: Show unread inbox summary (sender, subject, date).\""
        "    cliHelp: \"gws gmail +triage --help\""
        "Show unread inbox summary (sender, subject, date)"
        "Show unread inbox summary"
        "gws gmail +triage --help"
        "gws gmail +triage\n```"
        "```bash\ngws gmail +triage\n"
        "| `--query` | — | — | Gmail search query (default: is:unread) |"
        "gws gmail +triage --max 5 --query 'from:boss'"
        "gws gmail +triage --format json | jq '.[].subject'"
        "gws gmail +triage --labels"
      ]
      [
        "description: \"Gmail: Show inbox summary (sender, subject, date).\""
        "    cliHelp: \"gws gmail +triage --query 'in:inbox' --help\""
        "Show inbox summary (sender, subject, date)"
        "Show inbox summary"
        "gws gmail +triage --query 'in:inbox' --help"
        "gws gmail +triage --query 'in:inbox'\n```"
        "```bash\ngws gmail +triage --query 'in:inbox'\n"
        "| `--query` | — | — | Gmail search query (recommended: in:inbox) |"
        "gws gmail +triage --max 5 --query 'in:inbox from:boss'"
        "gws gmail +triage --query 'in:inbox' --format json | jq '.[].subject'"
        "gws gmail +triage --query 'in:inbox' --labels"
      ]
      (builtins.readFile (googleWorkspaceSkill "gws-gmail-triage"))
  );
  businessSkills = pkgs.linkFarm "hermes-agent-business-skills" [
    {
      name = "business/SKILL.md";
      path = pkgs.writeText "business-SKILL.md" ''
        ---
        name: business
        description: Business operations workflows for CRM, accounting, and Google Workspace.
        ---

        Business mode for accounting, CRM, and Google Workspace tasks.

        Use the CRM, Google Workspace, task-tracking, and Actual Budget MCP tools when the work calls for them.
      '';
    }
    {
      name = "crm-cli/SKILL.md";
      path = "${inputs.crm-cli}/skills/SKILL.md";
    }
    {
      name = "tasks/SKILL.md";
      path = pkgs.writeText "tasks-SKILL.md" ''
        ---
        name: tasks
        description: Capture concrete commitments, follow-ups, and verification steps without turning discussion into busywork.
        ---

        ${taskSkill}
      '';
    }
    {
      name = "gws-shared/SKILL.md";
      path = googleWorkspaceSkill "gws-shared";
    }
    {
      name = "gws-drive/SKILL.md";
      path = googleWorkspaceSkill "gws-drive";
    }
    {
      name = "gws-gmail/SKILL.md";
      path = googleWorkspaceSkill "gws-gmail";
    }
    {
      name = "gws-calendar/SKILL.md";
      path = googleWorkspaceSkill "gws-calendar";
    }
    {
      name = "gws-sheets/SKILL.md";
      path = googleWorkspaceSkill "gws-sheets";
    }
    {
      name = "gws-tasks/SKILL.md";
      path = googleWorkspaceSkill "gws-tasks";
    }
    {
      name = "gws-drive-upload/SKILL.md";
      path = googleWorkspaceSkill "gws-drive-upload";
    }
    {
      name = "gws-gmail-triage/SKILL.md";
      path = gmailTriageSkill;
    }
    {
      name = "gws-calendar-agenda/SKILL.md";
      path = googleWorkspaceSkill "gws-calendar-agenda";
    }
    {
      name = "gws-workflow-meeting-prep/SKILL.md";
      path = googleWorkspaceSkill "gws-workflow-meeting-prep";
    }
  ];
in
{
  sops.secrets = {
    "actual-budget-mcp-password" = {
      owner = config.services.hermes-agent.user;
      inherit (config.services.hermes-agent) group;
    };
    "actual-budget-mcp-sync-id" = {
      owner = config.services.hermes-agent.user;
      inherit (config.services.hermes-agent) group;
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

  codyos.hermes-agent.skillDirs = [ businessSkills ];
}
