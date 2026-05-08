{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;

  karakeepMcp = pkgs.writeShellApplication {
    name = "karakeep-mcp";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      export KARAKEEP_API_ADDR="https://karakeep.homehub.tv"
      KARAKEEP_API_KEY="$(< ${config.sops.secrets.karakeep-api-key.path})"
      export KARAKEEP_API_KEY

      exec npx -y @karakeep/mcp "$@"
    '';
  };
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  options.codyos.hermes-agent.skillDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = "Category-owned skill directories exposed to Hermes.";
  };

  config = {
    sops = {
      secrets = {
        "karakeep-api-key" = {
          owner = config.services.hermes-agent.user;
          inherit (config.services.hermes-agent) group;
        };
        "opencode-zen-api-key" = { };
        "hermes-discord-bot-token" = { };
        "hermes-discord-allowed-users" = { };
        "hermes-telegram-bot-token" = { };
        "hermes-telegram-allowed-users" = { };
      };
      templates."hermes-env" = {
        content = ''
          OPENCODE_ZEN_API_KEY=${config.sops.placeholder."opencode-zen-api-key"}
          DISCORD_BOT_TOKEN=${config.sops.placeholder."hermes-discord-bot-token"}
          DISCORD_ALLOWED_USERS=${config.sops.placeholder."hermes-discord-allowed-users"}
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder."hermes-telegram-bot-token"}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder."hermes-telegram-allowed-users"}
        '';
      };
    };

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
      };
      environmentFiles = [ config.sops.templates."hermes-env".path ];
      mcpServers.karakeep.command = "${karakeepMcp}/bin/karakeep-mcp";
      documents = {
        inherit soulFile;
        "AGENTS.md" = ''
          Operate as a NixOS-native assistant.

          Prefer direct inspection before recommendations.
          Common language runtimes may be absent; use `nix shell` only when a required runtime is missing.
          Do not use `nix shell` for standard Unix utilities that are already present.
        '';
      };
      settings = {
        model = {
          default = "kimi-k2.5";
          provider = "opencode-zen";
        };
        max_turns = 100;
        terminal = {
          backend = "local";
          cwd = ".";
          timeout = 180;
        };
        platforms.discord.home_channel = {
          platform = "discord";
          chat_id = "1502095470334578779";
          name = "#bot-updates";
        };
        toolsets = [ "all" ];
        agent = {
          max_turns = 60;
          reasoning_effort = "medium";
        };
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
        };
        skills.external_dirs = config.codyos.hermes-agent.skillDirs ++ [
          inputs.cognitive-assistant.lib.operational.skillsDir
          inputs.cognitive-assistant.lib.existential.skillsDir
        ];
      };
    };
  };
}
