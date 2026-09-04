{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  nixosConfigRoot = "/etc/nixos";
  obsidianVault = "/data/knowledge/Personal";
  projectsRoot = "/data/projects";
  artifacts = inputs.cognitive-assistant.lib.artifacts;
  inherit (artifacts) operational existential;
  inherit (config.services.hermes-agent)
    group
    stateDir
    user
    workingDirectory
    ;
  inherit (artifacts.alignment) translationLayer;
  humanProfilesDir = "${workingDirectory}/human-profiles";
  existentialProfileFile = pkgs.writeText "hermes-existential-human-profile.md" (
    builtins.readFile existential.humanProfile
  );
  operationalProfileFile = pkgs.writeText "hermes-operational-human-profile.md" (
    builtins.readFile operational.humanProfile
  );
  agentsDocument = ''
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
  '';
  hermesSoulFile = pkgs.writeText "hermes-agent-soul.md" ''
    ${builtins.readFile translationLayer}

    # Hermes Environment

    ${agentsDocument}
  '';
in

{
  config = {
    services.hermes-agent.documents = {
      "MEMORY-SPEC.md" = builtins.readFile operational.toolSpecs.memory;
      "TASK-SPEC.md" = builtins.readFile operational.toolSpecs.tasks;
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
