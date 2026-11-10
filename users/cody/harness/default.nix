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
    ./opencode
    ./mcp.nix
  ];

  home.packages = [
    # Harness Packages
    pkgs.codex
    llmPkgs.pi
    llmPkgs.cursor-agent
    llmPkgs.muse-code

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

  # tuicr: match stylix catppuccin-mocha palette
  xdg.configFile."tuicr/config.toml".source = ./tuicr.toml;
}
