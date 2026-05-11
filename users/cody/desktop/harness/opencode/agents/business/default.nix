{
  imports = [
    ./skills/google-workspace
    ./skills/crm
    ./skills/tasks
  ];

  programs.opencode.agents.business = ''
    ---
    description: Business operations agent for CRM, accounting, and Google Workspace workflows.
    mode: subagent
    ---
    Business mode for accounting, CRM, and Google Workspace tasks.
  '';
}
