{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  inherit (inputs.cognitive-assistant.lib.operational.toolSpecs) memory;
  operationalPromptFile = inputs.cognitive-assistant.lib.operational.systemPromptFile;
  existentialPromptFile = inputs.cognitive-assistant.lib.existential.systemPromptFile;

  obsidianVault = "/home/codyt/Knowledge/Personal";

  skillSeedDirs = config.codyos.hermes-agent.skillDirs ++ [
    inputs.cognitive-assistant.lib.operational.skillsDir
    inputs.cognitive-assistant.lib.existential.skillsDir
  ];
  skillSeedDirArgs = lib.escapeShellArgs (map toString skillSeedDirs);
in
{
  imports = [
    inputs.hermes-agent.nixosModules.default
    ./hermes-mcp.nix
  ];

  options.codyos.hermes-agent.skillDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = "Category-owned skill directories seeded into Hermes' mutable skill store.";
  };

  config = {
    sops = {
      secrets = {
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
        KNOWLEDGE_PERSONAL = obsidianVault;
        OBSIDIAN_VAULT = obsidianVault;
      };
      environmentFiles = [ config.sops.templates."hermes-env".path ];
      documents = {
        "SOUL.md" = soulFile;
        "USER.md" = pkgs.writeText "USER.md" ''
          ${builtins.readFile existentialPromptFile}
          ${builtins.readFile operationalPromptFile}
        '';
        "MEMORY.md" = memory; # Guidelines on what to save. Hermes uses state dir MEMORY.md
        "AGENTS.md" = ''
          # Environment

          - NixOS-native assistant
          - Default workspace: ${config.services.hermes-agent.workingDirectory}
          - HERMES_HOME: runtime state only (sessions, memories, skills, auth, config)
          - Do not treat /var/lib/hermes as project workspace unless explicitly asked
          - Common language runtimes may be absent; use `nix shell` only when required
          - Do not use `nix shell` for standard Unix utilities

          # Core Documents

          - **SOUL.md**: Core operating principles
          - **USER.md**: User patterns, preferences, decision-making frameworks
          - **MEMORY.md**: A list of what counts to save as durable objects in memory

          # Skills Integration

          **Critical**: Check skills proactively for any situation requiring understanding of user preferences, patterns, or decision-making style.

          Load relevant skills when requests involve:
          - Decision support or strategic thinking
          - Interpersonal dynamics or business strategy
          - Scoped inspection or diagnosis
          - User's work style or operating preferences
          - Any situation requiring judgment calls aligned with user values

          Available user-pattern skills:
          - additive-thinking-partner
          - inspect-before-prescribe
          - intuition-backfill-mode
          - match-mode-to-request
          - ship-and-sell-bias
          - diagnose-before-patching
          - relational-and-faith-register
          - bind-to-operator

          Do not wait for explicit user questions about themselves. If a task requires understanding how the user thinks, prefers to work, or would handle a situation—check skills first.
        '';
        "OBSIDIAN.md" = ''
          # Obsidian Vault Location

          Personal vault: ${obsidianVault}

          - Use this absolute path for Obsidian, markdown, and QMD work
          - Do not infer vault location from HOME
          - HOME and HERMES_HOME belong to the Hermes service account, not Cody's vault
        '';
      };
      settings = {
        model = {
          default = "kimi-k2.5";
          provider = "opencode-zen";
        };
        display.tool_progress = "off";
        max_turns = 100;
        terminal = {
          backend = "local";
          cwd = config.services.hermes-agent.workingDirectory;
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
        toolsets = [ "all" ];
        agent = {
          max_turns = 60;
          reasoning_effort = "medium";
        };
        memory = {
          memory_enabled = true;
          user_profile_enabled = true;
          provider = "holographic";
        };
        plugins = {
          "hermes-memory-store" = {
            auto_extract = false;
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
        skills.external_dirs = [ ];
      };
    };
  };
}
