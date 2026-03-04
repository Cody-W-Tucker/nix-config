{ inputs, pkgs, ... }:

{
  imports = [
    ./opencode
    ./mcp.nix
  ];

  home.packages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    qmd
    agent-browser
    coderabbit-cli
    rtk
    openspec
  ];
}
