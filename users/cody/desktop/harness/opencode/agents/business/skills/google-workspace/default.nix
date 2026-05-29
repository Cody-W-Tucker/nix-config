{ inputs, lib, ... }:

let
  skillsRoot = "${inputs.googleworkspace-cli}/skills";
  skill = name: builtins.readFile "${skillsRoot}/${name}/SKILL.md";
  gwsSkills = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = skill name;
      })
      (
        lib.pipe (builtins.readDir skillsRoot) [
          (lib.filterAttrs (name: type: type == "directory" && lib.hasPrefix "gws-" name))
          builtins.attrNames
          (lib.sort (a: b: a < b))
        ]
      )
  );
in
{
  # Curated Google Workspace skills from the pinned upstream flake.
  programs.opencode.skills = gwsSkills // {
    # Keep inbox triage tuned for agent use while preserving the full upstream
    # sibling layout (`gws-gmail-read`, `gws-gmail-reply`, etc.).
    gws-gmail-triage =
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
        (skill "gws-gmail-triage");
  };
}
