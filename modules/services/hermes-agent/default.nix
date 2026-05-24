{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  inherit (config.codyos.hermes-agent.locations) nixosConfigRoot obsidianVault projectsRoot;
  inherit (config.services.hermes-agent)
    group
    stateDir
    user
    workingDirectory
    ;
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./filesystem-access.nix
    ./hermes-mcp.nix
    ./cron-wake.nix
    ./toolsets
    ./skills
  ];

  config = {
    codyos.hermes-agent.cronWake.enable = true;

    sops = {
      secrets = {
        "opencode-api-key" = { };
        "xai-api-key" = { };
        "firecrawl-api-key" = { };
        "hermes-discord-bot-token" = { };
        "hermes-discord-allowed-users" = { };
        "hermes-telegram-bot-token" = { };
        "hermes-telegram-allowed-users" = { };
      };
      templates."hermes-env" = {
        content = ''
          OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
          XAI_API_KEY=${config.sops.placeholder."xai-api-key"}
          FIRECRAWL_API_KEY=${config.sops.placeholder."firecrawl-api-key"}
          DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes-discord-bot-token"}
          DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes-discord-allowed-users"}
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes-telegram-bot-token"}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes-telegram-allowed-users"}
        '';
      };
    };
    systemd.services.hermes-agent = {
      restartTriggers = [
        # Force restart when declarative settings or SOUL change. The upstream
        # module writes config.yaml and workspace documents via activation script
        # but does not restart the service afterward.
        (pkgs.writeText "hermes-agent-config-trigger" (
          builtins.toJSON config.services.hermes-agent.settings
        ))
        soulFile
      ];
      environment = {
        # The packaged Hermes runtime is missing bundled web plugin manifests
        # (and the xai web plugin entirely), so force plugin discovery to read
        # from the pinned source tree where the full plugins/ dir exists.
        HERMES_BUNDLED_PLUGINS = "${inputs.hermes-agent}/plugins";

        # faster-whisper's ctranslate2 CUDA path needs the NVIDIA driver libs
        # and CUDA runtime visible at runtime; these are provided by the host,
        # not the sealed Hermes venv.
        LD_LIBRARY_PATH = lib.concatStringsSep ":" [
          "/run/opengl-driver/lib"
          "/run/current-system/sw/lib"
          (lib.makeLibraryPath [ pkgs.libopus ])
        ];
      };
      serviceConfig = {
        TimeoutStopSec = 210;
        UnsetEnvironment = [ "MESSAGING_CWD" ];
      };
    };

    # Hermes loads its primary identity from HERMES_HOME/SOUL.md, not from the
    # workspace documents directory.
    system.activationScripts.hermes-agent-soul = lib.stringAfter [ "hermes-agent-setup" ] ''
      install -o ${user} -g ${group} -m 0640 ${soulFile} ${stateDir}/.hermes/SOUL.md
    '';

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      package = llmPkgs.hermes-agent;
      extraPackages = with pkgs; [
        binutils
        curl
        glibc.bin
        jq
        libopus
        nix
        python3Minimal
      ];
      environment = {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = "127.0.0.1";
        API_SERVER_PORT = "8642";
        API_SERVER_KEY = "local-only";
        OBSIDIAN_VAULT = obsidianVault;
      };
      environmentFiles = [ config.sops.templates."hermes-env".path ];
      configFile = pkgs.writeText "hermes-config.json" (
        # Make config.yaml fully declarative. Upstream merges generated settings
        # into any existing config when configFile is null, which preserves stale
        # runtime keys like old skills.external_dirs entries. Writing the final
        # settings JSON here forces activation to overwrite config.yaml instead.
        builtins.toJSON config.services.hermes-agent.settings
      );
      documents = {
        "AGENTS.md" = ''
          You are the Cognitive Assistant for the user. Your job is to extend his thinking and execution in a grounded, inspectable way that aligns with how he already operates.

          Default to the shortest complete answer. Elaborate only when asked or when omission would block the next action.

          # Environment

          - **Default workspace**: ${workingDirectory} (your shared working directory)
          - **NixOS config repo**: ${nixosConfigRoot} (this repo; you can inspect and edit it when needed)
          - **Obsidian vault**: ${obsidianVault} (shared space for saves/reads the user can also edit)
          - **Projects root**: ${projectsRoot} (user projects likely live here)
          - Common language runtimes may be absent; use `nix shell` only when required
          - Do NOT use `nix shell` for standard Unix utilities
        '';
      };
      settings = {
        model = {
          default = "grok-4.3";
          provider = "xai-oauth";
        };
        fallback_model = {
          model = "kimi-k2.6";
          provider = "opencode-go";
        };
        auxiliary = {
          vision = {
            provider = "opencode-go";
            model = "deepseek-v4-flash";
          };
          approval = {
            provider = "opencode-go";
            model = "deepseek-v4-flash";
          };
          mcp = {
            provider = "opencode-go";
            model = "deepseek-v4-flash";
          };
          title_generation = {
            provider = "opencode-go";
            model = "deepseek-v4-flash";
          };
          triage_specifier = {
            provider = "opencode-go";
            model = "kimi-k2.6";
          };
          kanban_decomposer = {
            provider = "opencode-go";
            model = "kimi-k2.6";
          };
          profile_describer = {
            provider = "opencode-go";
            model = "kimi-k2.6";
          };
          curator = {
            provider = "opencode-go";
            model = "kimi-k2.6";
          };
        };
        display.platforms = {
          discord = {
            tool_progress = "off";
          };
        };
        max_turns = 100;
        terminal = {
          backend = "local";
          cwd = workingDirectory;
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
          disabled = [ "google_chat-platform" ];
          "hermes-memory-store" = {
            auto_extract = true;
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
  };
}
