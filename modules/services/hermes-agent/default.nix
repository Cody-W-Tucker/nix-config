{
  config,
  inputs,
  pkgs,
  ...
}:

let
  inherit (config.services.hermes-agent) workingDirectory;
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
    ./runtime
    ./mcp
    ./secrets
    ./documents
    ./toolsets
    ./skills
    ./dashboard
  ];

  config = {
    # Upstream renamed this option: puts the `hermes` CLI into user packages
    # (was `addToSystemPackages`).
    programs.hermes-agent.enable = true;
    # Login shells inherit the same home the user units use.
    # Without this, an unwrapped `hermes` CLI writes ~/.hermes instead.
    home.sessionVariables.HERMES_HOME = config.services.hermes-agent.hermesHome;
    services.hermes-agent = {
      enable = true;
      gateway.enable = true;
      # User-scoped persistent state: HERMES_HOME and the agent workspace both
      # live under the user's XDG data directory. Upstream's HM activation
      # creates both directories and merges config/secrets/documents into them.
      hermesHome = "${config.xdg.dataHome}/hermes";
      workingDirectory = "${config.xdg.dataHome}/hermes/workspace";
      extraDependencyGroups = [
        "edge-tts"
        "firecrawl"
        "messaging"
      ];
      extraPackages = with pkgs; [
        binutils
        chromium
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser
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
        # Satisfies tools.browser_tool_install._chromium_installed without a
        # Playwright cache write into the immutable hermes-agent-env.
        AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
        VOICE_TOOLS_OPENAI_KEY = "local-only";
        MEALIE_BASE_URL = "https://mealie.homehub.tv";
        # Token is HASS_TOKEN in the multiline `hermes` sops secret (not a
        # sibling like mealie-api-key). Built-in ha_* tools enable when set.
        HASS_URL = "http://127.0.0.1:8123";
      };
      environmentFiles = [
        config.sops.templates."hermes-env".path
        config.sops.templates."hermes-agent-env".path
      ];
      settings = {
        model = {
          default = "grok-4.6";
          provider = "xai-oauth";
        };
        fallback_model = {
          provider = "opencode-go";
          model = "deepseek-v4-pro";
        };
        auxiliary = {
          approval = {
            provider = "opencode-go";
            model = "hy3";
          };
          compression = {
            provider = "opencode-go";
            model = "hy3";
          };
          web_extract = {
            provider = "opencode-go";
            model = "hy3";
          };
          curator = {
            provider = "opencode-go";
            model = "hy3";
            extra_body = {
              thinking.type = "enabled";
              reasoning_effort = "medium";
            };
          };
          title_generation = {
            provider = "opencode-go";
            model = "hy3";
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
          timeout = 600;
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
          auto_tts = false;
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
          reasoning_effort = "low";
          service_tier = "fast";
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
