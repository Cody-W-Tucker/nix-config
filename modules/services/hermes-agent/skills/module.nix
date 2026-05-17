{
  config,
  inputs,
  lib,
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
in
{
  options.codyos.hermes-agent.skills = {
    seedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Skill directories to seed into Hermes' mutable local skills tree.";
    };

    userPatternSkillList = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = "Rendered list of Cognitive Assistant user-pattern skills for the Hermes AGENTS document.";
    };
  };

  config = {
    codyos.hermes-agent.skills = {
      seedDirs = cognitiveAssistantSkillDirs;
      userPatternSkillList = cognitiveAssistantSkillList;
    };

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
      "github-auth"
      "github-code-review"
      "github-issues"
      "github-pr-workflow"
      "github-repo-management"
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
      "opencode"
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
