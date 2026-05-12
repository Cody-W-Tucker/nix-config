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

  externalSkillDirs = config.codyos.hermes-agent.skillDirs ++ [
    inputs.cognitive-assistant.lib.operational.skillsDir
    inputs.cognitive-assistant.lib.existential.skillsDir
  ];
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./hermes-mcp.nix
  ];

  options.codyos.hermes-agent.skillDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = "Category-owned skill directories exposed to Hermes as external skills.";
  };

  config = {
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
          OPENCODE_API_KEY=${config.sops.placeholder."opencode-api-key"}
          DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes-discord-bot-token"}
          DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes-discord-allowed-users"}
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes-telegram-bot-token"}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes-telegram-allowed-users"}
        '';
      };
    };

    system.activationScripts.hermes-agent-obsidian-permissions = lib.stringAfter [ "users" ] ''
      if [ -d "${obsidianVault}" ]; then
        ${pkgs.acl}/bin/setfacl -x u:${config.services.hermes-agent.user} /home/codyt 2>/dev/null || true
        ${pkgs.acl}/bin/setfacl -R -x u:${config.services.hermes-agent.user} "${obsidianVault}" 2>/dev/null || true
        find "${obsidianVault}" -type d -exec ${pkgs.acl}/bin/setfacl -x d:u:${config.services.hermes-agent.user} {} + 2>/dev/null || true

        chgrp -hR users "${obsidianVault}"
        chmod -R u+rwX,g+rwX "${obsidianVault}"
        find "${obsidianVault}" -type d -exec chmod g+s {} +
      fi
    '';
    users.users.${config.services.hermes-agent.user}.extraGroups = [ "users" ];

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      workingDirectory = "/mnt/work/dev/hermes";
      extraPackages = with pkgs; [
        curl
        jq
        libopus
        nix
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
          ${builtins.readFile existentialPromptFile}
          ${builtins.readFile operationalPromptFile}
        '';
        "MEMORY.md" = memory; # Guidelines on what to save. Hermes uses state dir MEMORY.md
        "TASKS.md" = tasks; # Tasks style
        "AGENTS.md" = ''
          # Environment

          - NixOS-native assistant
          - Default workspace: ${config.services.hermes-agent.workingDirectory}
          - HERMES_HOME: runtime state only (sessions, memories, skills, auth, config)
          - Do not treat /var/lib/hermes as project workspace unless explicitly asked
          - Common language runtimes may be absent; use `nix shell` only when required
          - Do not use `nix shell` for standard Unix utilities

          # Core Documents

          - **SOUL.md**: Core operating principles
          - **USER.md**: User patterns, preferences, decision-making frameworks
          - **MEMORY.md**: A list of what counts to save as durable objects in memory
          - **TASKS.md": Instructions on how to save tasks for the user.

          # Skills Integration

          **Critical**: Check skills proactively for any situation requiring understanding of user preferences, patterns, or decision-making style.

          Load relevant skills when requests involve:
          - Decision support or strategic thinking
          - Interpersonal dynamics or business strategy
          - Scoped inspection or diagnosis
          - User's work style or operating preferences
          - Any situation requiring judgment calls aligned with user values

          Available user-pattern skills:
          - additive-thinking-partner
          - inspect-before-prescribe
          - intuition-backfill-mode
          - match-mode-to-request
          - ship-and-sell-bias
          - diagnose-before-patching
          - relational-and-faith-register
          - bind-to-operator

          Do not wait for explicit user questions about themselves. If a task requires understanding how the user thinks, prefers to work, or would handle a situation—check skills first.
        '';
        "OBSIDIAN.md" = ''
          # Obsidian Vault Location

          Personal vault: ${obsidianVault}

          - Use this absolute path for Obsidian, markdown, and QMD work
          - Do not infer vault location from HOME
          - HOME and HERMES_HOME belong to the Hermes service account, not Cody's vault
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
          cwd = config.services.hermes-agent.workingDirectory;
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
        skills.external_dirs = map toString externalSkillDirs;
      };
    };
  };
}
