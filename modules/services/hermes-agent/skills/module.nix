{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cognitiveAssistantSkillDirs = [
    inputs.cognitive-assistant.lib.operational.skillsDir
    inputs.cognitive-assistant.lib.existential.skillsDir
  ];

  cognitiveAssistantSkillNames = lib.pipe cognitiveAssistantSkillDirs [
    (map (dir: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir))))
    lib.flatten
    lib.unique
    (lib.sort (a: b: a < b))
  ];

  cognitiveAssistantSkillList = lib.concatMapStringsSep "\n" (
    name: "- ${name}"
  ) cognitiveAssistantSkillNames;

  operationalSkillNames = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (
      builtins.readDir inputs.cognitive-assistant.lib.operational.skillsDir
    )
  );

  existentialSkillNames = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (
      builtins.readDir inputs.cognitive-assistant.lib.existential.skillsDir
    )
  );

  categorizedSkillLinks =
    category: root: names:
    map (name: {
      name = "${category}/${name}/SKILL.md";
      path = "${root}/${name}/SKILL.md";
    }) names;

  operationalSkills = pkgs.linkFarm "hermes-agent-operational-skills" (
    categorizedSkillLinks "operational" inputs.cognitive-assistant.lib.operational.skillsDir
      operationalSkillNames
  );

  existentialSkills = pkgs.linkFarm "hermes-agent-existential-skills" (
    categorizedSkillLinks "existential" inputs.cognitive-assistant.lib.existential.skillsDir
      existentialSkillNames
  );

in
{
  options.codyos.hermes-agent.skills = {
    skillPacks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable name for this Hermes skill pack.";
            };

            root = lib.mkOption {
              type = lib.types.path;
              description = "Root directory containing Hermes-style skill directories.";
            };

            mode = lib.mkOption {
              type = lib.types.enum [
                "mutable"
                "managed"
              ];
              default = "mutable";
              description = ''
                How the pack is copied into Hermes' local skill tree.

                mutable: copy only when the local skill is absent or malformed; local agent edits survive.
                managed: replace the local skill from the pack on each activation; Nix is source of truth.
              '';
            };

          };
        }
      );
      default = [ ];
      description = "Declarative Hermes skill packs to seed into the mutable local skills tree.";
    };

    seedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Legacy mutable skill directories to seed into Hermes' local skills tree.";
    };

    userPatternSkillList = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = "Rendered list of Cognitive Assistant user-pattern skills for the Hermes AGENTS document.";
    };
  };

  config = {
    codyos.hermes-agent.skills = {
      skillPacks = [
        {
          name = "cognitive-assistant-operational";
          root = operationalSkills;
          mode = "managed";
        }
        {
          name = "cognitive-assistant-existential";
          root = existentialSkills;
          mode = "managed";
        }
      ];
      userPatternSkillList = cognitiveAssistantSkillList;
    };

    # A malformed local skill directory without SKILL.md shadows the bundled
    # skill of the same name. This happened with hermes-agent: only references/
    # existed under the local tree, so the enabled bundled skill could not load.
    system.activationScripts.hermes-agent-clean-malformed-skills = lib.stringAfter [ "users" ] ''
      local_skills_root="${config.services.hermes-agent.stateDir}/.hermes/skills"

      for rel_dir in autonomous-ai-agents/hermes-agent; do
        skill_dir="$local_skills_root/$rel_dir"
        if [ -d "$skill_dir" ] && [ ! -e "$skill_dir/SKILL.md" ]; then
          rm -rf "$skill_dir"
        fi
      done
    '';

    services.hermes-agent.settings.skills.disabled = [
      "airtable"
      "apple-notes"
      "apple-reminders"
      "architecture-diagram"
      # "arxiv"
      "ascii-art"
      "ascii-video"
      "audiocraft"
      "baoyu-comic"
      "baoyu-infographic"
      "blogwatcher"
      "claude-code"
      "claude-design"
      "codebase-inspection"
      "codex"
      "comfyui"
      "creative-ideation"
      "debugging-hermes-tui-commands"
      "design-md"
      "dogfood"
      "dspy"
      "excalidraw"
      "findmy"
      "gif-search"
      # "github-auth"
      # "github-code-review"
      # "github-issues"
      # "github-pr-workflow"
      # "github-repo-management"
      "godmode"
      "google-workspace"
      "heartmula"
      # "hermes-agent"
      # "hermes-agent-skill-authoring"
      "himalaya"
      "huggingface-hub"
      # "humanizer"
      "imessage"
      "jupyter-live-kernel"
      # "kanban-orchestrator"
      # "kanban-worker"
      "linear"
      "llama-cpp"
      "llm-wiki"
      "lm-evaluation-harness"
      "macos-computer-use"
      "manim-video"
      "maps"
      "minecraft-modpack-server"
      "nano-pdf"
      "native-mcp"
      "node-inspect-debugger"
      "notion"
      "obliteratus"
      "obsidian"
      "ocr-and-documents"
      # "opencode"
      "openhue"
      "p5js"
      "pixel-art"
      "plan"
      "pokemon-player"
      "polymarket"
      "popular-web-designs"
      "powerpoint"
      "pretext"
      "python-debugpy"
      "requesting-code-review"
      "research-paper-writing"
      "segment-anything"
      "sketch"
      "songsee"
      "songwriting-and-ai-music"
      "spike"
      "spotify"
      "subagent-driven-development"
      "systematic-debugging"
      "teams-meeting-pipeline"
      "test-driven-development"
      "touchdesigner-mcp"
      "vllm"
      "webhook-subscriptions"
      "weights-and-biases"
      "writing-plans"
      "xurl"
      # "youtube-content"
      "yuanbao"
    ];
  };
}
