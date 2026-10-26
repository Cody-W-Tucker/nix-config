{
  config,
  inputs,
  pkgs,
  ...
}:

let
  nixosConfigRoot = "/etc/nixos";
  artifacts = inputs.cognitive-assistant.lib.artifacts;
  inherit (artifacts) operational existential;
  inherit (config.services.hermes-agent) hermesHome;
  inherit (artifacts.alignment) translationLayer;
  existentialProfileFile = pkgs.writeText "hermes-existential-human-profile.md" (
    builtins.readFile existential.humanProfile
  );
  operationalProfileFile = pkgs.writeText "hermes-operational-human-profile.md" (
    builtins.readFile operational.humanProfile
  );
  brevityInstructions = ''
    Be direct: match the length of your reply to the weight of the ask — a one-line question gets a one-line answer, and finished work gets a short report of what changed, what's verified, and what's left, never a replay of the process.
    No filler ("Great question," "I'd be happy to"), no restating the request back, no re-summarizing what you already said, no narrating tool calls the user can see. 
    Plain claims over adjectives; when unsure, say so plainly. Agree because it's right, not because the user said it. Depth is earned — give it when the user asks for detail, teaches, or the stakes demand it, not by default.
    Look up only what can materially change the answer, and stop when there is enough to answer accurately. 
    For execution, diagnosis, current facts, and verification, do the necessary investigation even when the request is short.
  '';
  agentsDocument = ''
    # Hermes Environment

    Hermes is running in a declarative NixOS environment with a Home Manager service.
    Persistent configuration lives in `${nixosConfigRoot}/modules/services/hermes-agent`, and mutable runtime state lives under `${hermesHome}`.
    You can inspect and edit the NixOS repo, but you cannot rebuild from here. Changes only persist when they are written back to the repo.

    # Environment

    This is a minimal environment. Common language runtimes may not be globally available.
    Use `nix shell` only when a required tool or runtime is missing.
    Do not use `nix shell` for standard Unix utilities that are typically available, such as `bash`, `coreutils`, `grep`, `sed`, `awk`, or `git`.
  '';
  hermesSoulFile = pkgs.writeText "hermes-agent-soul.md" ''
    ${brevityInstructions}

    ${builtins.readFile translationLayer}

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
