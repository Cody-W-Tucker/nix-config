{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  normalizeLocalSkills = pkgs.writeShellScript "hermes-normalize-local-skills" ''
    set -eu

    skills_dir="${config.services.hermes-agent.stateDir}/.hermes/skills"

    if [ ! -d "$skills_dir" ]; then
      exit 0
    fi

    chown -R ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} "$skills_dir"
    find "$skills_dir" -type d -exec chmod 2770 {} +
    find "$skills_dir" -type f -exec chmod u+rw,g+rw,o-rwx {} +
  '';
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
  skillDirs = [
    ./skills
    inputs.cognitive-assistant.lib.operational.skillsDir
    inputs.cognitive-assistant.lib.existential.skillsDir
  ];
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  sops = {
    secrets = {
      "karakeep-api-key" = {
        owner = config.services.hermes-agent.user;
        group = config.services.hermes-agent.group;
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
    extraPackages = with pkgs; [
      curl
      jq
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
      skills.external_dirs = skillDirs;
    };
  };

  system.activationScripts."hermes-agent-soulfile" = lib.stringAfter [ "hermes-agent-setup" ] ''
    install -o ${config.services.hermes-agent.user} \
      -g ${config.services.hermes-agent.group} \
      -m 0644 \
      -D ${soulFile} \
      ${config.services.hermes-agent.stateDir}/.hermes/SOUL.md

    ${normalizeLocalSkills}
  '';

  systemd.services.hermes-agent.serviceConfig.ExecStartPost = [ normalizeLocalSkills ];
}
