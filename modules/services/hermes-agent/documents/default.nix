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
        - **Extended Human Profiles**: The user maintains detailed profiles in your workspace. Consult (with targeted search) if a deeper understanding on the user's theory of mind would produce measurable better results for highly personalized tasks or conversations.
        - **Projects root**: ${projectsRoot} (user projects likely live here)
        - Common language runtimes may be absent; use `nix shell` only when required
        - Do NOT use `nix shell` for standard Unix utilities

        # Memory

        - The full memory tool spec lives in `MEMORY-TOOL.md`. Follow it when deciding what to store, update, delete, or ignore.
        - Default to the shared Mem0 memory provider for durable memory work so OpenCode and Hermes can both read and build on the same memory base.
        - Use built-in `memory` only when the note should stay Hermes-local or belong in Hermes snapshots rather than the shared cross-agent store.
        - Prefer storing memory in `mem0` when it should matter across future sessions, tools, or agents.
        - When a stable snapshot note and a shared `mem0` fact are both useful, write both deliberately.
      '';

      "MEMORY-TOOL.md" = builtins.readFile operational.toolSpecs.memory;
      "EXISTENTIAL-HUMAN-PROFILE.md" = builtins.readFile existential.humanProfile;
      "OPERATIONAL-HUMAN-PROFILE.md" = builtins.readFile operational.humanProfile;
    };

    # Hermes loads its primary identity from HERMES_HOME/SOUL.md, not from the
    # workspace documents directory.
    system.activationScripts.hermes-agent-soul = lib.stringAfter [ "hermes-agent-setup" ] ''
      install -o ${user} -g ${group} -m 0640 ${hermesSoulFile} ${stateDir}/.hermes/SOUL.md
    '';

    systemd.services.hermes-agent.restartTriggers = [ hermesSoulFile ];
  };
}
