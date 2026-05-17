{ inputs, pkgs, ... }:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  skill = name: "${llmPkgs.agent-browser}/share/agent-browser/skill-data/${name}";
in
{
  programs.opencode.skills = {
    agent-browser-core = skill "core";
    agent-browser-dogfood = skill "dogfood";
  };

  home.packages = [
    llmPkgs.agent-browser
  ];
}
