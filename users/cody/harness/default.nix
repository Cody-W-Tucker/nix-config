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
    llmPkgs.spec-kit
    llmPkgs.gnhf
    llmPkgs.pi
    llmPkgs.code-review-graph
    llmPkgs.tuicr
    llmPkgs.cursor-agent
    llmPkgs.deja-vu # session search across all agents
    pkgs.codex
  ];

  # tuicr: match stylix catppuccin-mocha palette
  xdg.configFile."tuicr/config.toml".source = ./tuicr.toml;
}
