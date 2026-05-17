{ inputs, pkgs, ... }:

let
  agentBrowser = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser;
  skill = name: "${agentBrowser}/share/agent-browser/skill-data/${name}";
  agentBrowserSkills = pkgs.linkFarm "hermes-agent-browser-skills" [
    {
      name = "core";
      path = skill "core";
    }
    {
      name = "dogfood";
      path = skill "dogfood";
    }
  ];
in
{
  services.hermes-agent.extraPackages = [ agentBrowser ];

  codyos.hermes-agent.skills.seedDirs = [ agentBrowserSkills ];
}
