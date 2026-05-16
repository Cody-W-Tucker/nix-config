{
  inputs,
  pkgs,
  self,
  ...
}:

let
  skillHelper = import "${self}/modules/shared/skill-adaptations.nix" { inherit inputs pkgs; };
  layer = inputs.cognitive-assistant.lib.operational;
in
{
  programs.opencode.skills = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = skillHelper.applyToText name (builtins.readFile (layer.skillFile name));
    }) layer.skillNames
  );
}
