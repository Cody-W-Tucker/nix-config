{ inputs, pkgs, ... }:

let

  crmSkills = pkgs.linkFarm "hermes-agent-crm-skills" [
    {
      name = "business/SKILL.md";
      path = pkgs.writeText "business-SKILL.md" ''
        ---
        name: business
        description: Business operations workflows for CRM, accounting, and Google Workspace.
        ---

        Business mode for accounting, CRM, and Google Workspace tasks.

        Use the CRM, Google Workspace, and task-tracking tools when the work calls for them.
      '';
    }
    {
      name = "crm-cli/SKILL.md";
      path = "${inputs.crm-cli}/skills/SKILL.md";
    }
  ];
in
{
  codyos.hermes-agent.skills.seedDirs = [ crmSkills ];
}
