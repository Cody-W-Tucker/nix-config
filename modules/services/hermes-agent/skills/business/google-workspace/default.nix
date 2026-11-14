{
  inputs,
  pkgs,
  ...
}:

let
  googleWorkspaceSkillsRoot = inputs.googleworkspace-cli + "/skills";

  # Upstream ships ~45 gws-* skills; Hermes gets only these.
  gwsSkillNames = [
    "gws-shared"
    "gws-calendar"
    "gws-calendar-agenda"
    "gws-calendar-insert"
    "gws-gmail"
    "gws-gmail-read"
    "gws-gmail-reply"
    "gws-gmail-send"
    "gws-gmail-triage"
    "gws-people"
    "gws-tasks"
  ];

  # Triage defaults to the inbox instead of every unread message.
  gmailTriageSkillDir = pkgs.writeTextDir "SKILL.md" (
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
      (builtins.readFile (googleWorkspaceSkillsRoot + "/gws-gmail-triage/SKILL.md"))
  );

  patchedSkillDirs.gws-gmail-triage = gmailTriageSkillDir;

  googleWorkspaceSkills = pkgs.linkFarm "hermes-agent-google-workspace-skills" (
    map (name: {
      name = "tools/${name}";
      path = patchedSkillDirs.${name} or (googleWorkspaceSkillsRoot + "/${name}");
    }) gwsSkillNames
  );
in
{
  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "google-workspace-tools";
      root = googleWorkspaceSkills;
      mode = "managed";
    }
  ];
}
