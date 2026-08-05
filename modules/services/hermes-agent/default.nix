{
  config,
  inputs,
  pkgs,
  ...
}:

let
  obsidianVault = "/data/knowledge/Personal";
  inherit (config.services.hermes-agent) workingDirectory;
  # Absolute path the container can exec (/nix/store is mounted ro).
  # Container PATH does not include host profiles, so gateway.platforms.buzz
  # must pin cli_path rather than relying on `buzz` on PATH.
  buzzCli = inputs.buzz.packages.${pkgs.stdenv.hostPlatform.system}.buzz-cli;
  buzzRelayUrl = "https://buzz.homehub.tv";
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./runtime
    ./mcp
    ./secrets
    ./documents
    ./toolsets
    ./skills
    ./dashboard
  ];

  config = {
    services.hermes-agent = {
      enable = true;
      user = "codyt";
      group = "users";
      createUser = false;
      container = {
        enable = true;
        extraOptions = [
          "--device"
          "nvidia.com/gpu=all"
        ];
        extraVolumes = [
          "/mnt/projects:/data/projects:rw"
          "/mnt/knowledge:/data/knowledge:rw"
          "/etc/nixos:/etc/nixos:rw"
        ];
      };
      addToSystemPackages = true;
      extraDependencyGroups = [
        "edge-tts"
        "firecrawl"
        "messaging"
      ];
      extraPackages = with pkgs; [
        binutils
        buzzCli
        curl
        ffmpeg
        glibc.bin
        jq
        libopus
        nix
        python3Minimal
      ];
      environment = {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = "0.0.0.0";
        API_SERVER_PORT = "8642";
        OBSIDIAN_VAULT = obsidianVault;
        VOICE_TOOLS_OPENAI_KEY = "local-only";
        # Non-secret Buzz defaults (private key stays in hermes-env via SOPS).
        BUZZ_RELAY_URL = buzzRelayUrl;
        BUZZ_CLI_PATH = "${buzzCli}/bin/buzz";
      };
      environmentFiles = [ config.sops.templates."hermes-env".path ];
      configFile = pkgs.writeText "hermes-config.json" (
        # Make config.yaml fully declarative. Upstream merges generated settings
        # into any existing config when configFile is null, which preserves stale
        # runtime keys like old skills.external_dirs entries. Writing the final
        # settings JSON here forces activation to overwrite config.yaml instead.
        builtins.toJSON config.services.hermes-agent.settings
      );
      settings = {
        model = {
          default = "grok-4.5";
          provider = "xai-oauth";
        };
        fallback_model = {
          provider = "opencode-go";
          model = "deepseek-v4-pro";
        };
        auxiliary = {
          approval = {
            provider = "opencode-go";
            model = "mimo-v2.5";
          };
          compression = {
            provider = "opencode-go";
            model = "mimo-v2.5";
          };
          web_extract = {
            provider = "opencode-go";
            model = "mimo-v2.5";
          };
          curator = {
            provider = "opencode-go";
            model = "deepseek-v4-pro";
            extra_body = {
              thinking.type = "enabled";
              reasoning_effort = "medium";
            };
          };
          title_generation = {
            provider = "opencode-go";
            model = "mimo-v2.5";
          };
        };
        display.platforms = {
          discord = {
            tool_progress = "off";
          };
          # Keep Buzz channels on final answers, not tool chatter.
          buzz = {
            interim_assistant_messages = false;
            tool_progress = "off";
          };
        };
        max_turns = 100;
        terminal = {
          backend = "local";
          cwd = workingDirectory;
          timeout = 600;
        };
        discord = {
          require_mention = true; # Respond only when @mentioned
          auto_thread = true; # Isolate each conversation in a thread
          reactions = true; # Emoji reactions for processing state
          free_response_channels = [ ]; # Channels that respond without @mention
          home_channel = "1502095470334578779"; # hermes-home (text)
        };
        # Native Buzz platform (bundled plugin). hermes gateway setup is a no-go
        # here: configFile overwrites config.yaml on activation and .env is SOPS.
        gateway.platforms.buzz = {
          enabled = true;
          extra = {
            relay_url = buzzRelayUrl;
            cli_path = "${buzzCli}/bin/buzz";
            # Empty = all channels the agent identity has joined.
            channels = [ ];
            require_mention = true;
            allow_all_users = true;
            poll_interval = 4;
            transport = "auto";
          };
        };
        environment = {
          DISCORD_HOME_CHANNEL = "1502095470334578779";
        };
        voice = {
          auto_tts = true;
        };
        stt = {
          enabled = true;
          provider = "openai";
          openai = {
            api_key = "local-only";
            base_url = "http://nas:8081/v1";
            model = "whisper-medium";
          };
        };
        tts = {
          provider = "openai";
          openai = {
            api_key = "local-only";
            base_url = "http://nas:8081/v1";
            model = "kokoro-82m";
            voice = "af_heart";
          };
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
          provider = "holographic";
          user_profile_enabled = true;
        };
        plugins = {
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
