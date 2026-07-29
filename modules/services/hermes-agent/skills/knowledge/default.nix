{ inputs, pkgs, ... }:

let
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

  # Apply the llm-agents overlay to host pkgs so QMD is built with host pkgs
  # (stable for NAS), allowing CUDA unfree predicate to apply correctly.
  pkgsWithLlmAgents = pkgs.extend inputs.llm-agents.overlays.shared-nixpkgs;
in
{
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
