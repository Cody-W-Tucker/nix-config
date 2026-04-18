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
    llmPkgs.rtk
    llmPkgs.openspec
    llmPkgs.ck
    llmPkgs.qmd
  ];
}
