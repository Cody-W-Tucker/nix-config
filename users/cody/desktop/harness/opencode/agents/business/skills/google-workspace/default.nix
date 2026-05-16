{
  inputs,
  pkgs,
  self,
  ...
}:

let
  skillHelper = import "${self}/modules/shared/skill-adaptations.nix" { inherit inputs pkgs; };
  skill = name: builtins.readFile "${inputs.googleworkspace-cli}/skills/${name}/SKILL.md";
  adapt = name: text: skillHelper.applyToText name text;
in
{
  # Curated Google Workspace skills from the pinned upstream flake.
  programs.opencode.skills = {
    gws-shared = adapt "gws-shared" (skill "gws-shared");
    gws-drive = adapt "gws-drive" (skill "gws-drive");
    gws-gmail = adapt "gws-gmail" (skill "gws-gmail");
    gws-calendar = adapt "gws-calendar" (skill "gws-calendar");
    gws-sheets = adapt "gws-sheets" (skill "gws-sheets");
    gws-tasks = adapt "gws-tasks" (skill "gws-tasks");

    # Helper skills for common high-value workflows.
    gws-drive-upload = adapt "gws-drive-upload" (skill "gws-drive-upload");
    gws-gmail-triage = adapt "gws-gmail-triage" (
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
        (skill "gws-gmail-triage")
    );
    gws-calendar-agenda = adapt "gws-calendar-agenda" (skill "gws-calendar-agenda");
    gws-workflow-meeting-prep = adapt "gws-workflow-meeting-prep" (skill "gws-workflow-meeting-prep");
  };
}
