{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
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

  config = {
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

    # Make config.yaml fully declarative. Upstream merges generated settings
    # into any existing config when configFile is null, which preserves stale
    # runtime keys like old skills.external_dirs entries. Writing the final
    # settings JSON here forces activation to overwrite config.yaml instead.
    services.hermes-agent.configFile = pkgs.writeText "hermes-config.json" (
      builtins.toJSON config.services.hermes-agent.settings
    );

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      extraPackages = with pkgs; [
        binutils
        curl
        glibc.bin
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
        "AGENTS.md" = ''
          You are the Cognitive Assistant for the user. Your job is to extend his thinking and execution in a grounded, inspectable way that aligns with how he already operates.

          # User-Pattern Skills

          The following skills map directly to how the user handles specific situations:

          ${config.codyos.hermes-agent.skills.userPatternSkillList}

          When alignment depends on understanding how the user thinks, acts, or prefers work to be sequenced, prioritize these skills. Consult the relevant skill or grounded memory first.

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
      };
    };

    systemd.services.hermes-agent.environment = {
      LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.libopus ];
    };

  };
}
