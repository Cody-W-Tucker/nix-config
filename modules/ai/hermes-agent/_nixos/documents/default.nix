{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  nixosConfigRoot = "/etc/nixos";
  cfg = config.services.hermes-agent;
  hermesHome = "${cfg.stateDir}/.hermes";
  codyosClone = "${cfg.workingDirectory}/codyos";
  artifacts = inputs.cognitive-assistant.lib.artifacts;
  inherit (artifacts) operational existential;
  ca = inputs.cognitive-assistant.packages.${pkgs.stdenv.hostPlatform.system}.ca;
  caHome = "${cfg.stateDir}/cognitive-assistant";
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

    Hermes runs on the NAS as the `hermes` system user, from a declarative NixOS configuration.
    Persistent configuration lives in `${nixosConfigRoot}/modules/ai/hermes-agent`, and mutable runtime state lives under `${hermesHome}`.
    You reach the internet, but not this host's other services, the LAN, the tailnet or SSH, apart from the local services your tools are configured for. Cody's notes reach you through the QMD MCP server, not as files.
    `${nixosConfigRoot}` is the live CodyOS checkout. It is read-only to you: read it to see what is deployed, never edit it. You cannot rebuild or apply changes from here.

    # Changing CodyOS

    Make CodyOS changes in your own clone, `${codyosClone}`, with your normal file tools. Cody applies them; you only propose them.
    The clone's `origin` is `${nixosConfigRoot}`, the configuration deployed on this host. Pass `--offline` to `nix` commands: the inputs are already in the store.

    1. `git fetch origin && git switch -c inbox/<short-slug> origin/main`. One branch per request; never commit to `main`.
    2. Read the repo's `AGENTS.md` and the nearest one to the files you change, and follow them.
    3. Make the smallest change that does what was asked. Do not edit `docs/src/`; the no-mistakes pipeline writes the docs when Cody validates the branch.
    4. Run the cheapest check that can catch the likely failure (for example `nix eval` on the setting you changed for each affected host). If a check cannot run here, say so; do not claim it passed.
    5. Commit on the branch. Do not push, rebuild, or touch `${nixosConfigRoot}`.
    6. Reply with the branch name, what changed, what you verified, and what is still unverified.

    Requests often arrive as a reply to a note in Discord #inbox. The note says what got in the way, where, the evidence, and the change that would remove it. If you cannot see the note, ask Cody to paste it.

    # Environment

    This is a minimal environment. Common language runtimes may not be globally available.
    Use `nix shell` only when a required tool or runtime is missing.
    Do not use `nix shell` for standard Unix utilities that are typically available, such as `bash`, `coreutils`, `grep`, `sed`, `awk`, or `git`.
  '';
  soulPrefix = pkgs.writeText "ca-soul-prefix.md" ''
    ${brevityInstructions}

    ${builtins.readFile ../plugins/advanced-delegation/delegation-instructions.md}
  '';
  soulSuffix = pkgs.writeText "ca-soul-suffix.md" agentsDocument;
  gitConfig = (pkgs.formats.gitIni { }).generate "hermes-gitconfig" {
    user = {
      name = "Hermes";
      email = "hermes@${config.networking.hostName}";
    };
    safe.directory = nixosConfigRoot;
    init.defaultBranch = "main";
  };
in

{
  services.hermes-agent.documents = {
    "MEMORY-SPEC.md" = builtins.readFile operational.toolSpecs.memory;
    "TASK-SPEC.md" = builtins.readFile operational.toolSpecs.tasks;
    "human-profiles/EXISTENTIAL-HUMAN-PROFILE.md" = existentialProfileFile;
    "human-profiles/OPERATIONAL-HUMAN-PROFILE.md" = operationalProfileFile;
  };

  systemd.tmpfiles.rules = [ "d ${caHome} 2770 ${cfg.user} ${cfg.group} - -" ];
  systemd.services.hermes-agent = {
    environment = {
      CA_HOME = caHome;
      GIT_CONFIG_GLOBAL = gitConfig;
    };
    preStart = lib.mkAfter ''
      ${ca}/bin/ca soul compile --prefix-file ${soulPrefix} --suffix-file ${soulSuffix} --reason activation
      ${ca}/bin/ca soul link ${hermesHome}
      if [ ! -e ${codyosClone} ]; then
        ${lib.getExe pkgs.git} clone --no-local ${nixosConfigRoot} ${codyosClone} || \
          echo "Hermes could not seed its CodyOS clone; other tasks remain available" >&2
      fi
    '';
  };
}
