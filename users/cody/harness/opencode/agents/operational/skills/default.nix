{ inputs, ... }:

let
  layer = inputs.cognitive-assistant.lib.operational;
in
{
  programs.opencode.skills = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = builtins.readFile (layer.skillFile name);
    }) layer.skillNames
  );
}
