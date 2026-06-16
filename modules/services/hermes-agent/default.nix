{
  config,
  inputs,
  pkgs,
  ...
}:

let
  obsidianVault = "/home/codyt/Knowledge/Personal";
  inherit (config.services.hermes-agent) workingDirectory;
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./package
    ./runtime
    ./mcp
    ./secrets
    ./documents
    ./toolsets
    ./skills
  ];

  config = {
    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      extraDependencyGroups = [
        "edge-tts"
        "firecrawl"
        "messaging"
        "voice"
      ];
      extraPackages = with pkgs; [
        binutils
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
        API_SERVER_HOST = "127.0.0.1";
        API_SERVER_PORT = "8642";
        API_SERVER_KEY = "local-only";
        OBSIDIAN_VAULT = obsidianVault;
        VOICE_TOOLS_OPENAI_KEY = "local-only";
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
          default = "grok-4.3";
          provider = "xai-oauth";
        };
        fallback_model = {
          model = "kimi-k2.6";
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
        voice = {
          auto_tts = true;
        };
        stt = {
          enabled = true;
          provider = "openai";
          openai = {
            api_key = "local-only";
            base_url = "http://127.0.0.1:8081/v1";
            model = "whisper-medium";
          };
        };
        tts = {
          provider = "openai";
          openai = {
            api_key = "local-only";
            base_url = "http://127.0.0.1:8081/v1";
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
