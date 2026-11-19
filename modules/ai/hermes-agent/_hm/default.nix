{
  osConfig,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (osConfig.codyos.site) domain;
  workflowPackage = inputs.workflow.packages.${pkgs.stdenv.hostPlatform.system}.workflowCli;
  hermesCommon = import "${inputs.hermes-agent}/nix/moduleCommon.nix" { inherit lib; };
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
    inputs.cognitive-assistant.homeManagerModules.cognitive-assistant
    ./runtime
    ./plugins
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
      # WORKAROUND: Hermes patches 0.15.2, but patchelfUnstable already has the fix.
      # https://github.com/NousResearch/hermes-agent/issues
      # REVIEW-BY: 2026-12-15
      package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        pmPackages = lib.filterAttrs (_: lib.isDerivation) (
          pkgs.unstable.callPackage "${inputs.hermes-agent}/nix/pm-packages.nix" {
            patchelf = pkgs.unstable.patchelfUnstable // {
              overrideAttrs = _: pkgs.unstable.patchelfUnstable;
            };
          }
        );
      };
      # User-scoped persistent state: HERMES_HOME and the agent workspace both
      # live under the user's XDG data directory. Upstream's HM activation
      # creates both directories and merges config/secrets/documents into them.
      hermesHome = "${config.xdg.dataHome}/hermes";
      workingDirectory = "${config.xdg.dataHome}/hermes/workspace";
      # Install the rendered settings as the whole config.yaml on every
      # activation. Upstream's default deep-merges them into the file on disk,
      # which keeps keys Nix no longer supplies: removed MCP servers stayed live.
      configFile =
        (hermesCommon.mkConfigFiles {
          inherit pkgs;
          cfg = config.services.hermes-agent;
          inherit (config.services.hermes-agent) workingDirectory;
        }).generated;
      extraDependencyGroups = [
        "edge-tts"
        "firecrawl"
        "messaging"
      ];
      # NumPy and aiohttp are sealed into Hermes's dependency groups. Do not
      # inject them through extraPythonPackages: Hermes rejects duplicate
      # distributions at build time.
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
        workflowPackage
      ];
      environment = {
        API_SERVER_ENABLED = "true";
        API_SERVER_HOST = "0.0.0.0";
        API_SERVER_PORT = toString (import ../_endpoint.nix).port;
        # Satisfies tools.browser_tool_install._chromium_installed without a
        # Playwright cache write into the immutable hermes-agent-env.
        AGENT_BROWSER_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
        VOICE_TOOLS_OPENAI_KEY = "local-only";
        MEALIE_BASE_URL = "https://mealie.${domain}";
      };
      environmentFiles = [
        config.sops.templates."hermes-env".path
        config.sops.templates."hermes-agent-env".path
      ];
      settings = {
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
          web_extract = {
            provider = "custom";
            model = "qwen-3.5-9b";
            base_url = "http://127.0.0.1:8081/v1";
            api_key = "local-only";
          };
          # Metadata and archival work stay local.
          curator = {
            provider = "custom";
            model = "qwen-3.5-9b";
            base_url = "http://127.0.0.1:8081/v1";
            api_key = "local-only";
            extra_body = {
              reasoning_effort = "medium";
              thinking.type = "enabled";
            };
          };
          title_generation = {
            provider = "custom";
            model = "qwen-3.5-4b";
            base_url = "http://127.0.0.1:8081/v1";
            api_key = "local-only";
          };
          profile_describer = {
            provider = "custom";
            model = "qwen-3.5-4b";
            base_url = "http://127.0.0.1:8081/v1";
            api_key = "local-only";
          };
        };
        display = {
          in_app_tips = false;
          in_app_tours = false;
          platforms = {
            discord = {
              tool_progress = "off";
            };
          };
        };
        # Preferences that were set at runtime and lived only in config.yaml.
        # They are declared here because the file is now replaced whole.
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
        # Keep deterministic platform authorization broad, but disclose cold
        # schemas only when the model needs them. The bridge and compact
        # manifest remain stable; full schemas arrive through tool_search.
        tools.tool_search = {
          enabled = "on";
          listing = "auto";
          listing_max_tokens = 1200;
          search_default_limit = 5;
          max_search_limit = 15;
          # Extend Hermes's curated cold-tool default with delegation: its
          # schema is unusually large and it is episodic. Do not defer
          # terminal/file/web/browser/clarify/skills/memory: they are the
          # normal working set for the personal operator.
          defer = [
            "computer_use"
            "session_search"
            "image_generate"
            "todo_list"
            "process_manage"
            "cronjob_manage"
            # Cold capability-management tools. Keep skill discovery and
            # ordinary memory eager; defer only their rare mutation/query APIs.
            "skill_manage"
            "fact_store"
            "vision_analyze"
            # Defer every browser backend variant. The active browser-use
            # backend exposes browser_exec; the named variants cover a later
            # switch to Hermes's native CDP browser backend.
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
          require_mention = true; # Respond only when @mentioned
          auto_thread = true; # Isolate each conversation in a thread
          reactions = true; # Emoji reactions for processing state
          free_response_channels = [ ]; # Channels that respond without @mention
          home_channel = "1502095470334578779"; # hermes-home (text)
        };
        environment = {
          DISCORD_HOME_CHANNEL = "1502095470334578779";
          TELEGRAM_HOME_CHANNEL = "8369015005"; # Cody Tucker DM
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
            model = "parakeet-tdt-v3";
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
        capabilities.file_modifier = {
          enabled = true;
          allowed_paths = [ "/etc/nixos/*" ];
        };
      };
    };
  };
}
