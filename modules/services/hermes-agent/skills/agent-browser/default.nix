{
  inputs,
  pkgs,
  self,
  ...
}:

let
  skillHelper = import "${self}/modules/shared/skill-adaptations.nix" { inherit inputs pkgs; };
  agentBrowser = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  skill = name: "${agentBrowser}/share/agent-browser/skill-data/${name}";
  rawAgentBrowserSkills = pkgs.linkFarm "hermes-agent-browser-skills" [
    {
      name = "core";
      path = skill "core";
    }
    {
      name = "dogfood";
      path = skill "dogfood";
    }
  ];
  agentBrowserSkills = skillHelper.adaptSkillDir {
    sourceDir = rawAgentBrowserSkills;
    outputName = "hermes-agent-browser-skills-adapted";
  };
in
{
  services.hermes-agent.extraPackages = [ agentBrowser ];

  codyos.hermes-agent.skillDirs = [ agentBrowserSkills ];
}
