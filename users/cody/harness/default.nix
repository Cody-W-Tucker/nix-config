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
    inputs.treehouse.packages.${pkgs.stdenv.hostPlatform.system}.treehouse
    llmPkgs.no-mistakes # Git push gate: runs an AI-driven validation pipeline, then opens a clean PR.
    llmPkgs.spec-kit
    llmPkgs.gnhf
    llmPkgs.pi
    llmPkgs.code-review-graph
    llmPkgs.tuicr
    llmPkgs.cursor-agent
    llmPkgs.deja-vu # session search across all agents
    pkgs.sqlite # Deja Vu reads OpenCode and Hermes session databases with sqlite3.
    pkgs.codex
  ];

  # Codex, OpenCode and Pi discover the shared Agent Skills directory.
  home.file.".agents/skills/deja-search".source = "${llmPkgs.deja-vu.src}/skills/deja-search";

  # Pi loads extensions from its user extension directory. Keep the upstream
  # extension and its adjacent helper together at the pinned package revision.
  home.file.".pi/agent/extensions/deja".source = "${llmPkgs.deja-vu.src}/extensions/pi";

  # tuicr: match stylix catppuccin-mocha palette
  xdg.configFile."tuicr/config.toml".source = ./tuicr.toml;
}
