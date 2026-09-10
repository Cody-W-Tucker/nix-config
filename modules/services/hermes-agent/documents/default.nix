{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  nixosConfigRoot = "/etc/nixos";
  artifacts = inputs.cognitive-assistant.lib.artifacts;
  inherit (artifacts) operational existential;
  inherit (config.services.hermes-agent) hermesHome workingDirectory;
  inherit (artifacts.alignment) translationLayer;
  existentialProfileFile = pkgs.writeText "hermes-existential-human-profile.md" (
    builtins.readFile existential.humanProfile
  );
  operationalProfileFile = pkgs.writeText "hermes-operational-human-profile.md" (
    builtins.readFile operational.humanProfile
  );
  agentsDocument = ''
    Hermes is running in a declarative NixOS environment with a Home Manager service.
    Persistent configuration lives in `${nixosConfigRoot}/modules/services/hermes-agent`, and mutable runtime state lives under `${hermesHome}`.
    You can inspect and edit the NixOS repo, but you cannot rebuild from here. Changes only persist when they are written back to the repo.

    # Environment

    This is a minimal environment. Common language runtimes may not be globally available.
    Use `nix shell` only when a required tool or runtime is missing.
    Do not use `nix shell` for standard Unix utilities that are typically available, such as `bash`, `coreutils`, `grep`, `sed`, `awk`, or `git`.
  '';
  hermesSoulFile = pkgs.writeText "hermes-agent-soul.md" ''
    ${builtins.readFile translationLayer}

    # Hermes Environment

    ${agentsDocument}
  '';
in

{
  config = {
    # Workspace documents: upstream installs each key (subdirectories allowed)
    # under workingDirectory via its hermes-agent-setup activation.
    services.hermes-agent.documents = {
      "MEMORY-SPEC.md" = builtins.readFile operational.toolSpecs.memory;
      "TASK-SPEC.md" = builtins.readFile operational.toolSpecs.tasks;
      "human-profiles/EXISTENTIAL-HUMAN-PROFILE.md" = existentialProfileFile;
      "human-profiles/OPERATIONAL-HUMAN-PROFILE.md" = operationalProfileFile;
    };

    # Hermes loads its primary identity from HERMES_HOME/SOUL.md, not from the
    # workspace documents directory. Upstream replaces the NixOS
    # system.activationScripts path with the declarative hermesHomeFiles
    # surface; files land user-owned (0600) after hermes-agent-setup.
    services.hermes-agent.hermesHomeFiles."SOUL.md" = hermesSoulFile;
  };
}
