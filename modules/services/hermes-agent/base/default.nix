{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  inherit (inputs.cognitive-assistant.lib.operational) systemPromptFile;

  workspaceDir = "/mnt/work/dev/hermes";
  obsidianVault = "/home/codyt/Knowledge/Personal";

  skillSeedDirs = config.codyos.hermes-agent.skillDirs ++ [
    inputs.cognitive-assistant.lib.operational.skillsDir
    inputs.cognitive-assistant.lib.existential.skillsDir
  ];
  skillSeedDirArgs = lib.escapeShellArgs (map toString skillSeedDirs);

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
    description = "Category-owned skill directories seeded into Hermes' mutable skill store.";
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

    system.activationScripts = {
      hermes-agent-seed-skills = lib.stringAfter [ "hermes-agent-setup" ] ''
        skills_dir="${config.services.hermes-agent.stateDir}/.hermes/skills"
        mkdir -p "$skills_dir"
        chown ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} "$skills_dir"
        chmod 2770 "$skills_dir"

        for src in ${skillSeedDirArgs}; do
          if [ ! -d "$src" ]; then
            continue
          fi

          while IFS= read -r -d "" skill_md; do
            skill_dir="$(dirname "$skill_md")"
            rel="''${skill_dir#$src/}"
            target="$skills_dir/$rel"

            if [ -e "$target/SKILL.md" ]; then
              continue
            fi

            mkdir -p "$(dirname "$target")"
            cp -aL "$skill_dir" "$target"
            chown -R ${config.services.hermes-agent.user}:${config.services.hermes-agent.group} "$target"
            chmod -R u+rwX,g+rwX,o-rwx "$target"
          done < <(find "$src" -name SKILL.md -print0)
        done
      '';

      hermes-agent-obsidian-access = lib.stringAfter [ "users" ] ''
        if [ -d "${obsidianVault}" ]; then
          ${pkgs.acl}/bin/setfacl -m u:${config.services.hermes-agent.user}:--x /home/codyt
          ${pkgs.acl}/bin/setfacl -R -m u:${config.services.hermes-agent.user}:rwX "${obsidianVault}"
          find "${obsidianVault}" -type d -exec ${pkgs.acl}/bin/setfacl -d -m u:${config.services.hermes-agent.user}:rwX {} +
        fi
      '';
    };

    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;
      workingDirectory = workspaceDir;
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
        KNOWLEDGE_PERSONAL = obsidianVault;
        OBSIDIAN_VAULT = obsidianVault;
      };
      environmentFiles = [ config.sops.templates."hermes-env".path ];
      mcpServers.karakeep.command = "${karakeepMcp}/bin/karakeep-mcp";
      documents = {
        "SOUL.md" = soulFile;
        "USER.md" = systemPromptFile;
        "AGENTS.md" = ''
          Operate as a NixOS-native assistant.

          Use ${workspaceDir} as the default workspace for terminal and file work.
          Use HERMES_HOME only for Hermes runtime state: sessions, memories, skills, auth, and config.
          Do not treat /var/lib/hermes as the user's project workspace unless explicitly asked.

          Prefer direct inspection before recommendations.
          Common language runtimes may be absent; use `nix shell` only when a required runtime is missing.
          Do not use `nix shell` for standard Unix utilities that are already present.
        '';
        "OBSIDIAN.md" = ''
          Personal Obsidian vault: ${obsidianVault}

          Use this absolute path for Obsidian, markdown, and QMD work. Do not infer the vault from HOME.
          HOME and HERMES_HOME belong to the Hermes service account, not Cody's Obsidian vault.
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
          cwd = workspaceDir;
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
        skills.external_dirs = [ ];
      };
    };
  };
}
