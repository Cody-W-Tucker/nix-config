{
  inputs,
  pkgs,
  self,
  ...
}:

let
  skillHelper = import "${self}/modules/shared/skill-adaptations.nix" { inherit inputs pkgs; };
in
{
  programs.opencode.skills = {
    crm-cli = skillHelper.applyToPath "crm-cli" "${inputs.crm-cli}/skills/SKILL.md";
  };
}
