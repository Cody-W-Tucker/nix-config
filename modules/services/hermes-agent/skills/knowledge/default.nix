{ inputs, pkgs, ... }:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  knowledgeSkillsDir = pkgs.linkFarm "hermes-agent-knowledge-skills" [
    {
      name = "tools/obsidian-bases/SKILL.md";
      path = ./note-taking/obsidian-bases/SKILL.md;
    }
    {
      name = "tools/obsidian-cli/SKILL.md";
      path = ./note-taking/obsidian-cli/SKILL.md;
    }
    {
      name = "tools/obsidian-markdown/SKILL.md";
      path = ./note-taking/obsidian-markdown/SKILL.md;
    }
    {
      name = "tools/qmd/SKILL.md";
      path = ./research/qmd/SKILL.md;
    }
  ];
in
{
  services.hermes-agent.extraPackages = [ llmPkgs.qmd ];

  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "knowledge-tools";
      root = knowledgeSkillsDir;
      mode = "managed";
      staleDirs = [
        "note-taking/obsidian-bases"
        "note-taking/obsidian-cli"
        "note-taking/obsidian-markdown"
        "research/qmd"
      ];
    }
  ];
}
