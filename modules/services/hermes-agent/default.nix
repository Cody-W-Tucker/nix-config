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
  caPackages = inputs.cognitive-assistant.packages.${pkgs.stdenv.hostPlatform.system} or { };
  crystallizePackage = lib.optional (caPackages ? crystallize) caPackages.crystallize;

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

  inherit (config.codyos.hermes-agent.locations) obsidianVault projectWorkspace projectsRoot;
  externalSkillDirs = config.codyos.hermes-agent.skillDirs ++ cognitiveAssistantSkillDirs;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./automations
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
    codyos.hermes-agent.automations.crystallize.enable = true;
    codyos.hermes-agent.cronWake.enable = true;

    sops = {
      secrets = {
        "opencode-api-key" = { };
        "xai-api-key" = { };
        "hermes-discord-bot-token" = { };
        "hermes-discord-allowed-users" = { };
        "hermes-telegram-bot-token" = { };
        "hermes-telegram-allowed-users" = { };
      };
      templates."hermes-env" = {
        content = ''
          OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
          XAI_API_KEY=${config.sops.placeholder."xai-api-key"}
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
      extraPackages =
        (with pkgs; [
          binutils
          curl
          glibc.bin
          jq
          libopus
          nix
          playwright-driver.browsers
        ])
        ++ crystallizePackage;
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
        "AGENTS.md" = ''
          You are the Cognitive Assistant for the user. Your job is to extend his thinking and execution in a grounded, inspectable way that aligns with how he already operates.

          # User-Pattern Skills

          The following skills map directly to how the user handles specific situations:

          ${cognitiveAssistantSkillList}

          When alignment depends on understanding how the user thinks, acts, or prefers work to be sequenced, prioritize these skills. Consult the relevant skill or grounded memory first.

          # Read-Only Skills

          Skills under `~/.hermes/skills/external-overlays/` are read-only upstream snapshots. The generated `SKILL.md` acts as a wrapper.

          - Do NOT edit the wrapper directly (writes will fail across rebuilds)
          - Save durable changes in `references/hermes-local-amendments.md` for that skill instead

          # Environment

          - **Default project workspace**: ${projectWorkspace} (your isolated workspace)
          - **Obsidian vault**: ${obsidianVault} (shared space for saves/reads the user can also edit)
          - **Projects root**: ${projectsRoot} (user projects likely live here)
          - Common language runtimes may be absent; use `nix shell` only when required
          - Do NOT use `nix shell` for standard Unix utilities
        '';
      };
      settings = {
        model = {
          default = "grok-4.3";
          provider = "x-ai";
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

    systemd.services.hermes-agent.environment = {
      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.libopus ];
    };

  };
}
