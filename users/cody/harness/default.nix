{
  inputs,
  pkgs,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in

{
  imports = [
    ./claude-code
    ./opencode
    ./context.nix
    ./mcp.nix
  ];

  home.packages = [
    # Harness Packages
    pkgs.codex
    llmPkgs.pi
    llmPkgs.cursor-agent
    llmPkgs.muse-code
    llmPkgs.grok

    # Agent workspace: persistent agent terminals. The NAS core is the shared
    # remote that Beast's herdr-app reaches over SSH; both use this pinned hc.
    llmPkgs.herdr-core

    # Memory and Session Management
    llmPkgs.deja-vu # session search across all agents
    pkgs.sqlite # Deja Vu reads OpenCode and Hermes session databases with sqlite3.

    # Git and Code Review
    llmPkgs.code-review-graph
    llmPkgs.tuicr
    llmPkgs.gnhf
    llmPkgs.no-mistakes # Git push gate: runs an AI-driven validation pipeline, then opens a clean PR.

    llmPkgs.spec-kit
    llmPkgs.backlog-md
  ];

  # Codex, OpenCode and Pi discover the shared Agent Skills directory.
  home.file.".agents/skills/deja-search".source = "${llmPkgs.deja-vu.src}/skills/deja-search";
  xdg.configFile."deja/exclude".text = ''
    harness:pi
  '';

  # Both harnesses use the skill shipped with the installed no-mistakes CLI.
  home.file.".agents/skills/no-mistakes/SKILL.md".source =
    "${llmPkgs.no-mistakes.src}/skills/no-mistakes/SKILL.md";

  # tuicr: match stylix catppuccin-mocha palette
  xdg.configFile."tuicr/config.toml".source = ./tuicr.toml;
}
