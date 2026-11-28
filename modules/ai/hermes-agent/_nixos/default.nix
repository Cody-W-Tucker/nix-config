{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  localEndpoint = {
    base_url = "http://127.0.0.1:8081/v1";
    api_key = "local-only";
  };
  localModel =
    model:
    localEndpoint
    // {
      provider = "custom";
      inherit model;
    };
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./runtime
    ./egress
    ./plugins
    ./mcp
    ./secrets
    ./documents
    ./toolsets
    ./dashboard
  ];

  codyos.workarounds.hermes-patchelf = {
    reason = "Hermes's pm-packages backport a patch onto patchelf 0.15.2; services.hermes-agent.package swaps in patchelfUnstable, which already has the fix.";
    upstream = "https://github.com/NousResearch/hermes-agent/pull/152542";
    reviewBy = "2027-01-15";
  };

  codyos.hermes-agent.egress.loopbackPorts = [
    8081
    config.services.mealie.port
  ];

  services.hermes-agent = {
    enable = true;
    package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
      pmPackages = lib.filterAttrs (_: lib.isDerivation) (
        pkgs.unstable.callPackage "${inputs.hermes-agent}/nix/pm-packages.nix" {
          patchelf = pkgs.unstable.patchelfUnstable // {
            overrideAttrs = _: pkgs.unstable.patchelfUnstable;
          };
        }
      );
    };
    workingDirectory = "${config.services.hermes-agent.stateDir}/workspace";
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
      API_SERVER_PORT = toString (import ../_endpoint.nix).port;
      AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
      VOICE_TOOLS_OPENAI_KEY = "local-only";
      MEALIE_BASE_URL = "http://127.0.0.1:${toString config.services.mealie.port}";
    };
    environmentFiles = [
      config.sops.templates."hermes-env".path
      config.sops.templates."hermes-agent-env".path
    ];
    settings = {
      skills.external_dirs = [ ];
      model = {
        default = "gpt-6.1-terra";
        provider = "openai-codex";
      };
      fallback_model = {
        provider = "xai-oauth";
        model = "grok-4.7";
      };
      auxiliary = {
        approval = {
          provider = "opencode-go";
          model = "gpt-5.6-luna";
        };
        compression = {
          provider = "opencode-go";
          model = "gpt-5.6-luna";
        };
        web_extract = localModel "qwen-3.5-9b";
        curator = localModel "qwen-3.5-9b" // {
          extra_body = {
            reasoning_effort = "medium";
            thinking.type = "enabled";
          };
        };
        title_generation = localModel "qwen-3.5-4b";
        profile_describer = localModel "qwen-3.5-4b";
      };
      display = {
        in_app_tips = false;
        in_app_tours = false;
        platforms.discord.tool_progress = "off";
      };
      telemetry.shared_metrics = {
        enabled = false;
        send = false;
        offer_version = 2;
      };
      gateway.multiplex_profiles = true;
      plugins.hermes-memory-store = {
        auto_extract = false;
        default_trust = 0.5;
      };
      max_turns = 100;
      tools.tool_search = {
        enabled = "on";
        listing = "auto";
        listing_max_tokens = 1200;
        search_default_limit = 5;
        max_search_limit = 15;
        defer = [
          "computer_use"
          "session_search"
          "image_generate"
          "todo_list"
          "process_manage"
          "cronjob_manage"
          "skill_manage"
          "fact_store"
          "vision_analyze"
          "browser_exec"
          "browser_navigate"
          "browser_snapshot"
          "browser_click"
          "browser_type"
          "browser_scroll"
          "browser_back"
          "browser_press"
          "browser_get_images"
          "browser_vision"
          "browser_console"
          "browser_cdp"
          "browser_dialog"
          "browser_vault"
          "drive_preview"
          "gui_tour"
          "desktop_preview"
          "annotate_preview"
          "manage_catalog"
          "show_tip"
          "desktop_project"
          "close_terminal"
          "set_theme"
          "read_terminal"
          "read_window_below"
          "focus_pane"
          "delegate_task"
        ];
      };
      discord = {
        require_mention = true;
        auto_thread = true;
        reactions = true;
        free_response_channels = [ ];
      };
      platforms = {
        discord.home_channel = {
          platform = "discord";
          chat_id = "1502095470334578779";
          name = "hermes-home";
        };
        telegram.home_channel = {
          platform = "telegram";
          chat_id = "8369015005";
          name = "Cody Tucker";
        };
      };
      environment = {
        DISCORD_HOME_CHANNEL = "1502095470334578779";
        TELEGRAM_HOME_CHANNEL = "8369015005";
      };
      voice = {
        auto_tts = false;
        client_direct = false;
      };
      stt = {
        enabled = true;
        provider = "openai";
        openai = localEndpoint // {
          model = "fluid-speech-pro-clean";
        };
      };
      tts = {
        provider = "openai";
        openai = localEndpoint // {
          model = "kokoro-82m";
          voice = "af_heart";
        };
      };
      agent = {
        max_turns = 60;
        reasoning_effort = "low";
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
        provider = "hindsight";
        user_profile_enabled = true;
      };
      compression = {
        enabled = true;
        threshold = 0.70;
        micro_compact = false;
      };
      checkpoints = {
        enabled = true;
        max_snapshots = 50;
      };
    };
  };
}
