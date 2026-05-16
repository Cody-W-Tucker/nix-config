{
  inputs,
  pkgs,
  self,
  ...
}:

let
  skillHelper = import "${self}/modules/shared/skill-adaptations.nix" { inherit inputs pkgs; };
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  rawKnowledgeSkillsDir = builtins.path {
    path = ./.;
    name = "hermes-agent-knowledge-skills";
  };
  knowledgeSkillsDir = skillHelper.adaptSkillDir {
    sourceDir = rawKnowledgeSkillsDir;
    outputName = "hermes-agent-knowledge-skills-adapted";
  };
in
{
  services.hermes-agent.extraPackages = [ llmPkgs.qmd ];

  codyos.hermes-agent.skillDirs = [ knowledgeSkillsDir ];
}
