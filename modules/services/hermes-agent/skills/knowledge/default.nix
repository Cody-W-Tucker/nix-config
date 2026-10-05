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
      rel = "tools/obsidian-bases";
      file = ./note-taking/obsidian-bases/SKILL.md;
    }
    {
      rel = "tools/obsidian-cli";
      file = ./note-taking/obsidian-cli/SKILL.md;
    }
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

  # Apply the llm-agents overlay to host pkgs so QMD is built with host pkgs
  # (stable for NAS), allowing CUDA unfree predicate to apply correctly.
  pkgsWithLlmAgents = pkgs.extend inputs.llm-agents.overlays.shared-nixpkgs;
in
{
  _module.args.allKnowledgeRelPaths = map (entry: entry.rel) allKnowledgeEntries;
  _module.args.filteredKnowledgeRelPaths = map (entry: entry.rel) filteredKnowledgeEntries;
  _module.args.filteredKnowledgeRoot = knowledgeSkillsDir;

  services.hermes-agent.extraPackages = [
    # Disable Vulkan to prevent node-llama-cpp enumeration crashes in container;
    # enable CUDA so QMD can use the host NVIDIA GPU passed through to the container.
    (pkgsWithLlmAgents.llm-agents.qmd.override {
      vulkanSupport = false;
      cudaSupport = true;
    })
  ];

  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "knowledge-tools";
      root = knowledgeSkillsDir;
      mode = "managed";
    }
  ];
}
