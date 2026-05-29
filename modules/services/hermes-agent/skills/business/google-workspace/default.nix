{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  googleWorkspaceSkillsRoot = "${inputs.googleworkspace-cli}/skills";
  googleWorkspaceSkill = name: "${googleWorkspaceSkillsRoot}/${name}/SKILL.md";

  gwsSkillNames = lib.pipe (builtins.readDir googleWorkspaceSkillsRoot) [
    (lib.filterAttrs (name: type: type == "directory" && lib.hasPrefix "gws-" name))
    lib.attrNames
    (lib.sort (a: b: a < b))
  ];

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

  gmailTriageSkillDir = pkgs.runCommand "gws-gmail-triage-skill" { } ''
    mkdir -p "$out"
    cp ${gmailTriageSkill} "$out/SKILL.md"
  '';

  customSkillDirs = {
    "gws-gmail-triage" = gmailTriageSkillDir;
  };

  googleWorkspaceSkills = pkgs.linkFarm "hermes-agent-google-workspace-skills" (
    map (name: {
      name = "tools/${name}";
      path = lib.attrByPath [ name ] "${googleWorkspaceSkillsRoot}/${name}" customSkillDirs;
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
