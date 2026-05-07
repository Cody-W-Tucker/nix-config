{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  skillDirs = [
    inputs.cognitive-assistant.lib.operational.skillsDir
    inputs.cognitive-assistant.lib.existential.skillsDir
  ];
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  sops = {
    secrets = {
      "opencode-zen-api-key" = { };
      "hermes-telegram-bot-token" = { };
      "hermes-telegram-allowed-users" = { };
    };
    templates."hermes-env" = {
      content = ''
        OPENCODE_ZEN_API_KEY=${config.sops.placeholder."opencode-zen-api-key"}
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
    environmentFiles = [ config.sops.templates."hermes-env".path ];
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
  '';
}
