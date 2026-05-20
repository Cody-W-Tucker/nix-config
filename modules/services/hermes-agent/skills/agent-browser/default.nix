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
  # Hermes' built-in browser toolset uses agent-browser under the hood and
  # otherwise falls back to mutable npm installs in its own runtime tree.
  # Keeping the packaged binary here gives Hermes a Nix-provided agent-browser
  # while we still seed the upstream browser skills from the same package.
  services.hermes-agent.extraPackages = [ agentBrowser ];

  codyos.hermes-agent.skills.seedDirs = [ agentBrowserSkills ];
}
