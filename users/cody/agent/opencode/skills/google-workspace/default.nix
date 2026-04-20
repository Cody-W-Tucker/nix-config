{ inputs, ... }:

let
  skill = name: builtins.readFile "${inputs.googleworkspace-cli}/skills/${name}/SKILL.md";
in
{
  # Curated Google Workspace skills from the pinned upstream flake.
  programs.opencode.skills = {
    gws-shared = skill "gws-shared";
    gws-drive = skill "gws-drive";
    gws-gmail = skill "gws-gmail";
    gws-calendar = skill "gws-calendar";
    gws-sheets = skill "gws-sheets";
    gws-tasks = skill "gws-tasks";

    # Helper skills for common high-value workflows.
    gws-drive-upload = skill "gws-drive-upload";
    gws-gmail-triage = skill "gws-gmail-triage";
    gws-calendar-agenda = skill "gws-calendar-agenda";
    gws-workflow-meeting-prep = skill "gws-workflow-meeting-prep";
  };
}
