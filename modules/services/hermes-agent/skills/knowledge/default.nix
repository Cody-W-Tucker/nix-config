{
  inputs,
  pkgs,
  lib,
  defaultExcludedSkillPaths,
  ...
}:

let
  allKnowledgeEntries = [
    {
      rel = "tools/obsidian-markdown";
      file = ./note-taking/obsidian-markdown/SKILL.md;
    }
    {
      rel = "tools/qmd";
      file = ./research/qmd/SKILL.md;
    }
    {
      rel = "research/research-state";
      file = ./research/research-state/SKILL.md;
    }
  ];

  filteredKnowledgeEntries = lib.filter (
    entry: !lib.elem entry.rel defaultExcludedSkillPaths
  ) allKnowledgeEntries;

  knowledgeSkillsDir = pkgs.linkFarm "hermes-agent-knowledge-skills" (
    map (entry: {
      name = "${entry.rel}/SKILL.md";
      path = entry.file;
    }) filteredKnowledgeEntries
  );

in
{
  _module.args.allKnowledgeRelPaths = map (entry: entry.rel) allKnowledgeEntries;
  _module.args.filteredKnowledgeRelPaths = map (entry: entry.rel) filteredKnowledgeEntries;

  services.hermes-agent.extraPackages = [
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd
  ];

  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "knowledge-tools";
      root = knowledgeSkillsDir;
      mode = "managed";
    }
  ];
}
