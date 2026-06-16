{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  nixosConfigRoot = "/etc/nixos";
  obsidianVault = "/home/codyt/Knowledge/Personal";
  projectsRoot = "/home/codyt/Projects";
  existential = inputs.cognitive-assistant.lib.existential;
  operational = inputs.cognitive-assistant.lib.operational;
  inherit (config.services.hermes-agent)
    group
    stateDir
    user
    workingDirectory
    ;
  inherit (inputs.cognitive-assistant.lib.alignment) soulFile;
  hermesSoulFile = pkgs.writeText "hermes-agent-soul.md" (builtins.readFile soulFile);
  humanProfilesDir = "${workingDirectory}/human-profiles";
  existentialProfileFile = pkgs.writeText "hermes-existential-human-profile.md" (
    builtins.readFile existential.humanProfile
  );
  operationalProfileFile = pkgs.writeText "hermes-operational-human-profile.md" (
    builtins.readFile operational.humanProfile
  );
in

{
  config = {
    services.hermes-agent.documents = {
      "AGENTS.md" = ''
        You are the Cognitive Assistant for the user. Your job is to extend his thinking and execution in a grounded, inspectable way that aligns with how he already operates.

        # Environment

        - **Default workspace**: ${workingDirectory} (your shared working directory)
        - **NixOS config repo**: ${nixosConfigRoot} (this repo; you can inspect and edit it when needed)
        - **Obsidian vault**: ${obsidianVault} (shared space for saves/reads the user can also edit)
        - **Miniflux**: use the Miniflux MCP tools for RSS triage.
        - **Knowledge search via `qmd`**: (your search tool access to the user's personal knowledge base)
        - **Extended Human Profiles**: in `${workingDirectory}/human-profiles/`. Search (via qmd) if a deeper understanding on the user's theory of mind would produce measurable better results for highly personalized tasks or conversations.
        - **Projects root**: ${projectsRoot} (user projects likely live here)
        - Common language runtimes may be absent; use `nix shell` only when required
        - Do NOT use `nix shell` for standard Unix utilities

        # Memory

        - The full memory tool spec lives in `MEMORY-TOOL.md`. Follow it when deciding what to store, update, delete, or ignore.
        - Use durable memory deliberately rather than by default.
      '';

      "MEMORY-TOOL.md" = builtins.readFile operational.toolSpecs.memory;
    };

    systemd.tmpfiles.rules = [
      "d ${humanProfilesDir} 0750 ${user} ${group} -"
    ];

    # Hermes loads its primary identity from HERMES_HOME/SOUL.md, not from the
    # workspace documents directory.
    system.activationScripts.hermes-agent-soul = lib.stringAfter [ "hermes-agent-setup" ] ''
      install -o ${user} -g ${group} -m 0640 ${hermesSoulFile} ${stateDir}/.hermes/SOUL.md
    '';

    system.activationScripts.hermes-agent-human-profiles = lib.stringAfter [ "hermes-agent-setup" ] ''
      install -d -o ${user} -g ${group} -m 0750 ${humanProfilesDir}
      install -o ${user} -g ${group} -m 0640 ${existentialProfileFile} ${humanProfilesDir}/EXISTENTIAL-HUMAN-PROFILE.md
      install -o ${user} -g ${group} -m 0640 ${operationalProfileFile} ${humanProfilesDir}/OPERATIONAL-HUMAN-PROFILE.md
    '';

    systemd.services.hermes-agent.restartTriggers = [
      hermesSoulFile
      existentialProfileFile
      operationalProfileFile
    ];
  };
}
