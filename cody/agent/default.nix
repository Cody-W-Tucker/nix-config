{ inputs, pkgs, ... }:

{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    qmd # Semantic search
    coderabbit-cli
    rtk # Token reducer for command-line tools
    openspec # Spec driven development tool
    ck # Semantic search for code
    inputs.roborev.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
