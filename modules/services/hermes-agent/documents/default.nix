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
  userPatternSkillNames =
    lib.pipe
      [
        inputs.cognitive-assistant.lib.operational.skillNames
        inputs.cognitive-assistant.lib.existential.skillNames
      ]
      [
        lib.flatten
        lib.unique
        (lib.sort (a: b: a < b))
      ];
  userPatternSkillList = lib.concatMapStringsSep "\n" (name: "- ${name}") userPatternSkillNames;
in

{
  config = {
    services.hermes-agent.documents = {
      "AGENTS.md" = ''
        Hermes is running in a declarative NixOS environment.
        Persistent configuration lives in `${nixosConfigRoot}/modules/services/hermes-agent`, and mutable runtime state lives under `${stateDir}/.hermes`.
        You can inspect and edit the NixOS repo, but you cannot rebuild from here. Changes only persist when they are written back to the repo.

        # Environment

        This is a minimal environment. Common language runtimes may not be globally available.
        Use `nix shell` only when a required tool or runtime is missing.
        Do not use `nix shell` for standard Unix utilities that are typically available, such as `bash`, `coreutils`, `grep`, `sed`, `awk`, or `git`.

        ## Working Context

        - **Default workspace**: `${workingDirectory}`
        - **Projects root**: `${projectsRoot}` for user projects
        - **Obsidian vault**: `${obsidianVault}` as a shared read/write space

        ## Tool Notes

        - **Miniflux**: use the Miniflux MCP instead of curling the Miniflux URL for RSS operations.
        - **Memory**: the full memory tool spec lives at `${workingDirectory}/MEMORY-TOOL.md`. Consult it before storing, updating, deleting, or ignoring memory entries.

        ## Personalization Sources

        When the user asks for your persective on a subject and user-specific context would materially improve the result, route like this:

        1. **Light personalization** (default): Use `qmd` against the `human-profiles` collection and the PKM/journal collections first.
        2. **Deeper personalization**: Load one or more of the high-salience user-pattern skills below when the situation matches their trigger conditions.

        High-salience user-pattern skills:

        ${userPatternSkillList}
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
