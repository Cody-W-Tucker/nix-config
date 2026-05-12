{ inputs, pkgs, ... }:

let
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

  googleWorkspaceSkills = pkgs.linkFarm "hermes-agent-google-workspace-skills" [
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
  codyos.hermes-agent.skillDirs = [ googleWorkspaceSkills ];
}
