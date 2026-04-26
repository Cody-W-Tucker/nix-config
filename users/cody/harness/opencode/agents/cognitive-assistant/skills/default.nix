{ inputs, ... }:

let
  skill = name: builtins.readFile (inputs.cognitive-assistant.lib.skillFile name);
in
{
  programs.opencode.skills = {
    user-context-model = skill "user-context-model";
    user-decision-support = skill "user-decision-support";
    user-growth-constraints = skill "user-growth-constraints";
    user-request-interpretation = skill "user-request-interpretation";
    user-response-calibration = skill "user-response-calibration";
  };
}
