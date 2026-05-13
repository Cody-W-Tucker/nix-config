{ inputs, pkgs, ... }:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  knowledgeSkillsDir = builtins.path {
    path = ./.;
    name = "hermes-agent-knowledge-skills";
  };
in
{
  services.hermes-agent.extraPackages = [ llmPkgs.qmd ];

  codyos.hermes-agent.skillDirs = [ knowledgeSkillsDir ];
}
