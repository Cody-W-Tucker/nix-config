{
  inputs,
  pkgs,
  self,
  ...
}:

let
  skillHelper = import "${self}/modules/shared/skill-adaptations.nix" { inherit inputs pkgs; };
  prompt =
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
in
{
  programs.opencode.skills.tasks = skillHelper.applyToText "tasks" (
    ''
      ---
      name: tasks
      description: Capture concrete commitments, follow-ups, and verification steps without turning discussion into busywork.
      ---

    ''
    + prompt
  );
}
