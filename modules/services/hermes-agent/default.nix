{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  skillDirs = [
    inputs.cognitive-assistant.lib.operational.skillsDir
    inputs.cognitive-assistant.lib.existential.skillsDir
  ];
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  sops.secrets."opencode-zen-api-key" = { };

  sops.templates."hermes-env" = {
    content = ''
      OPENAI_API_KEY=${config.sops.placeholder."opencode-zen-api-key"}
    '';
  };

  environment.systemPackages = [ hermesPackage ];

  services.hermes-agent = {
    enable = true;
    package = hermesPackage;
    environmentFiles = [ config.sops.templates."hermes-env".path ];
    extraPackages = with pkgs; [
      curl
      git
      jq
      nix
      ripgrep
    ];
    documents = {
      "SOUL.md" = soulFile;
      "AGENTS.md" = ''
        Operate as a NixOS-native assistant.

        Prefer direct inspection before recommendations.
        Common language runtimes may be absent; use `nix shell` only when a required runtime is missing.
        Do not use `nix shell` for standard Unix utilities that are already present.
      '';
    };
    config = {
      model = {
        default = "kimi-k2.5";
        provider = "custom";
        base_url = "https://opencode.ai/zen/v1";
      };
      terminal = {
        backend = "local";
        timeout = 180;
        lifetime_seconds = 300;
      };
      browser.inactivity_timeout = 120;
      agent = {
        max_turns = 60;
        reasoning_effort = "medium";
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
        memory_char_limit = 2200;
        user_char_limit = 1375;
        nudge_interval = 10;
      };
      compression = {
        enabled = true;
        threshold = 0.50;
        target_ratio = 0.20;
        protect_last_n = 20;
      };
      streaming.enabled = true;
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
