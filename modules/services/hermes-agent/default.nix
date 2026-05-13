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

  obsidianVault = "/home/codyt/Knowledge/Personal";
  projectWorkspace = "/mnt/work/dev/hermes";

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
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
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

    system.activationScripts.hermes-agent-obsidian-permissions = lib.stringAfter [ "users" ] ''
      if [ -d "${obsidianVault}" ]; then
        ${pkgs.acl}/bin/setfacl -m u:${config.services.hermes-agent.user}:--x /home/codyt
        ${pkgs.acl}/bin/setfacl -R -x u:${config.services.hermes-agent.user} "${obsidianVault}" 2>/dev/null || true
        find "${obsidianVault}" -type d -exec ${pkgs.acl}/bin/setfacl -x d:u:${config.services.hermes-agent.user} {} + 2>/dev/null || true

        chgrp -hR users "${obsidianVault}"
        ${pkgs.acl}/bin/setfacl -R -m g::rwX "${obsidianVault}"
        find "${obsidianVault}" -type d -exec ${pkgs.acl}/bin/setfacl -m d:g::rwx {} +
        chmod -R u+rwX,g+rwX "${obsidianVault}"
        find "${obsidianVault}" -type d -exec chmod g+s {} +
      fi
    '';
    users.users.${config.services.hermes-agent.user}.extraGroups = [ "users" ];

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
          # Environment

          - NixOS-native assistant
          - Default project workspace: ${projectWorkspace}
          - HERMES_HOME: runtime state only (sessions, memories, skills, auth, config)
          - Do not treat /var/lib/hermes/workspace as project workspace unless explicitly asked
          - Common language runtimes may be absent; use `nix shell` only when required
          - Do not use `nix shell` for standard Unix utilities

          # Core Documents

          - **SOUL.md**: Core operating principles
          - **USER.md**: User patterns, preferences, decision-making frameworks
          - **MEMORY.md**: A list of what counts to save as durable objects in memory
          - **TASKS.md**": Instructions on how to save tasks for the user.

          # Skills Integration

          **Critical**: Check skills proactively for any situation requiring understanding of user preferences, patterns, or decision-making style.

          Load relevant skills when requests involve:
          - Decision support or strategic thinking
          - Interpersonal dynamics or business strategy
          - Scoped inspection or diagnosis
          - User's work style or operating preferences
          - Any situation requiring judgment calls aligned with user values

          Available user-pattern skills:
          ${cognitiveAssistantSkillList}

          Do not wait for explicit user questions about themselves. If a task requires understanding how the user thinks, prefers to work, or would handle a situation—check skills first.
        '';
      };
      settings = {
        model = {
          default = "kimi-k2.5";
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
