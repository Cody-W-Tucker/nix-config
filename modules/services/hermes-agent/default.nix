{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  memoryToolSpec = builtins.readFile inputs.cognitive-assistant.lib.operational.toolSpecs.memory;
  inherit (config.codyos.hermes-agent.locations) nixosConfigRoot obsidianVault projectsRoot;
  inherit (config.services.hermes-agent)
    group
    stateDir
    user
    workingDirectory
    ;
  hermesSoul = builtins.readFile soulFile;
  hermesSoulFile = pkgs.writeText "hermes-agent-soul.md" hermesSoul;
  hermesPkgBase = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesPythonOverridePatchDir = builtins.path {
    path = ./patches;
    name = "hermes-agent-patches";
  };
  hermesPkg = hermesPkgBase.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      python_overrides="$out/share/hermes-agent/python-overrides"
      site_packages="${hermesPkgBase.passthru.hermesVenv}/lib/python3.12/site-packages"

      mkdir -p "$python_overrides"
      cp "$site_packages/hermes_constants.py" "$python_overrides/hermes_constants.py"
      cp "$site_packages/utils.py" "$python_overrides/utils.py"
      cp -rL "$site_packages/hermes_cli" "$python_overrides/hermes_cli"
      chmod -R u+w "$python_overrides"

      if [ ! -f "$python_overrides/hermes_constants.py" ] || [ ! -f "$python_overrides/hermes_cli/auth.py" ] || [ ! -f "$python_overrides/utils.py" ]; then
        echo "failed to locate Hermes auth sources in $out" >&2
        exit 1
      fi

      # This host intentionally shares HERMES_HOME between the hermes service
      # user and the codyt CLI via the hermes group, so keep the upstream
      # local patches explicit and reviewable in ./patches.
      for patch_file in ${hermesPythonOverridePatchDir}/*.patch; do
        patch -p1 -d "$python_overrides" < "$patch_file"
      done

      for bin_name in hermes hermes-agent hermes-acp; do
        wrapProgram "$out/bin/$bin_name" --prefix PYTHONPATH : "$python_overrides"
      done
    '';
  });

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
        hermesSoulFile
      ];
      environment = {
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
        UMask = "0007";
        UnsetEnvironment = [ "MESSAGING_CWD" ];
      };
    };

    # Hermes loads its primary identity from HERMES_HOME/SOUL.md, not from the
    # workspace documents directory.
    system.activationScripts.hermes-agent-soul = lib.stringAfter [ "hermes-agent-setup" ] ''
      install -o ${user} -g ${group} -m 0640 ${hermesSoulFile} ${stateDir}/.hermes/SOUL.md
    '';

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      package = hermesPkg;
      extraDependencyGroups = [
        "edge-tts"
        "firecrawl"
        "messaging"
        "voice"
      ];
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

          # Environment

          - **Default workspace**: ${workingDirectory} (your shared working directory)
          - **NixOS config repo**: ${nixosConfigRoot} (this repo; you can inspect and edit it when needed)
          - **Obsidian vault**: ${obsidianVault} (shared space for saves/reads the user can also edit)
          - **Knowledge search via `qmd`**: (your search tool access to the user's personal knowledge base)
          - **Projects root**: ${projectsRoot} (user projects likely live here)
          - Common language runtimes may be absent; use `nix shell` only when required
          - Do NOT use `nix shell` for standard Unix utilities

          # Memory

          - The full memory tool spec lives in `MEMORY-TOOL.md`. Follow it when deciding what to store, update, delete, or ignore.
          - Default to the shared `mem0` MCP server for durable memory work so OpenCode and Hermes can both read and build on the same memory base.
          - Use built-in `memory` only when the note should stay Hermes-local or belong in Hermes snapshots rather than the shared cross-agent store.
          - Prefer storing memory in `mem0` when it should matter across future sessions, tools, or agents.
          - When a stable snapshot note and a shared `mem0` fact are both useful, write both deliberately.
        '';
        "MEMORY-TOOL.md" = memoryToolSpec;
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
            extra_body = {
              thinking.type = "enabled";
              reasoning_effort = "medium";
            };
          };
          kanban_decomposer = {
            provider = "opencode-go";
            model = "kimi-k2.6";
            extra_body = {
              thinking.type = "enabled";
              reasoning_effort = "medium";
            };
          };
          profile_describer = {
            provider = "opencode-go";
            model = "kimi-k2.6";
            extra_body = {
              thinking.type = "enabled";
              reasoning_effort = "medium";
            };
          };
          curator = {
            provider = "opencode-go";
            model = "kimi-k2.6";
            extra_body = {
              thinking.type = "enabled";
              reasoning_effort = "medium";
            };
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
        curator = {
          enabled = true;
          interval_hours = 24 * 7;
          min_idle_hours = 2;
          stale_after_days = 30;
          archive_after_days = 90;
          backup = {
            enabled = true;
            keep = 5;
          };
        };
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
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
