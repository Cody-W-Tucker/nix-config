{ inputs, ... }:

let
  existential = inputs.cognitive-assistant.lib.existential;
  operational = inputs.cognitive-assistant.lib.existential;
in
{
  programs.opencode.skills = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = builtins.readFile (existential.skillFile name);
    }) existential.skillNames
    ++ map (name: {
      inherit name;
      value = builtins.readFile (operational.skillFile name);
    }) operational.skillNames
  );
}
