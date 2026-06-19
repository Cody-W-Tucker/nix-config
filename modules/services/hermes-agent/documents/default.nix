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
  artifacts = inputs.cognitive-assistant.lib.artifacts;
  inherit (artifacts) operational existential;
  inherit (config.services.hermes-agent)
    group
    stateDir
    user
    workingDirectory
    ;
  inherit (artifacts.alignment) soulFile;
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

    ## Tool Notes

    - **Memory and Tasks**: the full tool specs at `${workingDirectory}/MEMORY-SPEC.md` and `${workingDirectory}/TASK-SPEC.md`. Consult when managing memory and structuring tasks respectively.

    ### Internal Context Sources

    qmd is the primary source for internal knowledge stored in Obsidian-backed collections.

    If the user asks a factual or direct question that could plausibly be answered from internal knowledge, search qmd before saying you do not know.

    For internal knowledge questions:
    1. Search the most relevant qmd collections first.
    2. Run additional searches with adjacent terms, synonyms, project names, or likely note titles if the first search is thin.
    3. Synthesize the answer from the retrieved material when the evidence is sufficient, even if no single note states it verbatim.

    When the user asks for your persective on a subject and user-specific context would materially improve the result use `qmd` and synthesize an answer.

    Do not default to "I don't know" when the answer is likely in the knowledge base but has not been searched yet.
  '';
  hermesSoulFile = pkgs.writeText "hermes-agent-soul.md" ''
    ${builtins.readFile soulFile}

    # Hermes Environment

    ${agentsDocument}
  '';
in

{
  config = {
    services.hermes-agent.documents = {
      "AGENTS.md" = agentsDocument;
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
