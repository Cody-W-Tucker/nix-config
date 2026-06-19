{
  inputs,
  ...
}:

let
  skills = inputs.cognitive-assistant.lib.artifacts.skills.files;
in
{
  programs.opencode.skills = skills;
}
