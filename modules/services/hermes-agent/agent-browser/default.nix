{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  agentBrowser = inputs.llm-agents.packages.${system}.agent-browser;
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

  codyos.hermes-agent.skillDirs = [ agentBrowserSkills ];
}
