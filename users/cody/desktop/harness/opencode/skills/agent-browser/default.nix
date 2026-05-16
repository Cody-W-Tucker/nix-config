{
  inputs,
  pkgs,
  self,
  ...
}:

let
  skillHelper = import "${self}/modules/shared/skill-adaptations.nix" { inherit inputs pkgs; };
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  skill = name: "${llmPkgs.agent-browser}/share/agent-browser/skill-data/${name}";
in
{
  programs.opencode.skills = {
    agent-browser-core = skillHelper.applyToPath "agent-browser-core" (skill "core");
    agent-browser-dogfood = skillHelper.applyToPath "agent-browser-dogfood" (skill "dogfood");
  };

  home.packages = [
    llmPkgs.agent-browser
  ];
}
