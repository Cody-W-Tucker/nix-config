{ inputs, pkgs, ... }:

{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    qmd # Semantic search
    agent-browser
    coderabbit-cli
    rtk # Token reducer for command-line tools
    openspec # Spec driven development tool
    ck # Semantic search for code
  ];
}
