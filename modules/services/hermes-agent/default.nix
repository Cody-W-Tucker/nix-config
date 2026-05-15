{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  inherit (inputs.cognitive-assistant.lib.operational.toolSpecs) memory tasks;
  operationalPromptFile = inputs.cognitive-assistant.lib.operational.systemPromptFile;
  existentialPromptFile = inputs.cognitive-assistant.lib.existential.systemPromptFile;

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

  externalSkillDirs = config.codyos.hermes-agent.skillDirs ++ cognitiveAssistantSkillDirs;
  inherit (config.codyos.hermes-agent.locations) obsidianVault projectWorkspace projectsRoot;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./filesystem-access.nix
    ./hermes-mcp.nix
    ./cron-wake.nix
    ./skills
  ];

  options.codyos.hermes-agent.skillDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = "Category-owned skill directories exposed to Hermes as external skills.";
  };

  config = {
    codyos.hermes-agent.cronWake.enable = true;

    sops = {
      secrets = {
        "opencode-api-key" = { };
        "hermes-discord-bot-token" = { };
        "hermes-discord-allowed-users" = { };
        "hermes-telegram-bot-token" = { };
        "hermes-telegram-allowed-users" = { };
      };
      templates."hermes-env" = {
        content = ''
          OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
          DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes-discord-bot-token"}
          DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes-discord-allowed-users"}
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes-telegram-bot-token"}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes-telegram-allowed-users"}
        '';
      };
    };
    # Force restart when declarative settings change. The upstream module
    # writes config.yaml via activation script but does not restart the
    # service, so running agents keep stale in-memory config.
    systemd.services.hermes-agent.restartTriggers = [
      (pkgs.writeText "hermes-agent-config-trigger" (
        builtins.toJSON config.services.hermes-agent.settings
      ))
    ];

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      extraPackages = with pkgs; [
        curl
        jq
        libopus
        nix
        playwright-driver.browsers
      ];
      environment = {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = "127.0.0.1";
        API_SERVER_PORT = "8642";
        API_SERVER_KEY = "local-only";
        OBSIDIAN_VAULT = obsidianVault;
      };
      environmentFiles = [ config.sops.templates."hermes-env".path ];
      documents = {
        "SOUL.md" = soulFile;
        "USER.md" = pkgs.writeText "USER.md" ''
          # Dual Layer User Bio

          ## Existential Layer

          To understand what the user wants and how they see the world.

          ${builtins.readFile existentialPromptFile}

          ## Operational Layer

          To see how they work.

          ${builtins.readFile operationalPromptFile}
        '';
        "MEMORY.md" = memory; # Guidelines on what to save. Hermes uses state dir MEMORY.md
        "TASKS.md" = tasks; # Tasks style
        "AGENTS.md" = ''
          You are the Cognitive Assistant for the user. Your job is to extend his thinking and execution in a way that is grounded, inspectable, and aligned with how he already operates.

          # Document Roles

          Use the provided documents deliberately, not generically:

          - **SOUL.md**: Core stance. Inspect before asserting, diagnose before patching, collapse toward the simplest structure that works, and extend more often than you evaluate.
          - **USER.md**: Default read on the user's current patterns, commitments, and decision style. Use it to infer intent and pace, especially when the user is already farther along than the wording suggests.
          - **MEMORY.md**: Rules for what counts as durable memory. Memory is for grounded facts tied to named objects, operators, constraints, and decisions, not personality-building or chat recap.
          - **TASKS.md**: Rules for capturing real commitments. Tasks should stay concrete, ordered, and lean; do not turn orientation or speculation into task overhead.

          # Precedence

          - The user's current message and the artifact in front of you outrank summaries.
          - The user's own statements outrank generated profiles or secondhand descriptions.
          - If a claim cannot be tied to the current request, the inspected artifact, or a grounded user pattern, mark it as inference or do not make it.

          # Default Operating Mode

          - Assume the user usually wants extension, not a balanced menu of options.
          - If the user asked for inspection, touch the real thing first.
          - If the user asked for execution, do the work instead of planning around it.
          - If something is broken, name the cause before proposing the fix.
          - If scope tightens, tighten with it. Do not add polish or abstraction that was not earned.
          - Treat spiritual, philosophical, and symbolic language as part of the reasoning layer when it is doing real work. Engage the claim beneath it without mirroring the vocabulary back.

          # Skills

          Check skills proactively when the request depends on stance, preference, judgment, interpersonal reading, business framing, diagnosis, or mode selection.

          Available user-pattern skills:
          ${cognitiveAssistantSkillList}

          Do not wait for an explicit self-reflective question. If better alignment depends on understanding how the user thinks, commits, or wants the work sequenced, consult the relevant skill/document first.

          # Memory And Tasks

          - Save memory only when it is durable and likely to change future work.
          - Capture tasks only when there is a real commitment with an object, action, and deliverable.
          - For both memory and tasks, prefer the latest tightened constraint over blended summaries.

          # Environment

          - Default project workspace: ${projectWorkspace}
          - Accessible Obsidian vault: ${obsidianVault}
          - Accessible Projects root: ${projectsRoot}
          - Common language runtimes may be absent; use `nix shell` only when required
          - Do not use `nix shell` for standard Unix utilities
        '';
      };
      settings = {
        model = {
          default = "kimi-k2.6";
          provider = "opencode-go";
        };
        display.platforms = {
          discord = {
            tool_progress = "off";
          };
        };
        max_turns = 100;
        terminal = {
          backend = "local";
          cwd = projectWorkspace;
          timeout = 180;
        };
        discord = {
          require_mention = true; # Respond only when @mentioned
          auto_thread = true; # Isolate each conversation in a thread
          reactions = true; # Emoji reactions for processing state
          free_response_channels = [ ]; # Channels that respond without @mention
          home_channel = "1502095470334578779"; # hermes-home (text)
        };
        environment = {
          DISCORD_HOME_CHANNEL = "1502095470334578779";
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        };
        toolsets = [ "all" ];
        agent = {
          max_turns = 60;
          reasoning_effort = "medium";
        };
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
          provider = "holographic";
        };
        plugins = {
          "hermes-memory-store" = {
            auto_extract = false;
            default_trust = 0.5;
          };
        };
        compression = {
          enabled = true;
          threshold = 0.85;
        };
        checkpoints = {
          enabled = true;
          max_snapshots = 50;
        };
        skills = {
          external_dirs = map toString externalSkillDirs;
          disabled = [
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
      };
    };
  };
}
