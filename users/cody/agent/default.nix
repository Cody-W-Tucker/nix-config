{
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  llmPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) rlm-cli;
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
    llmPkgs.pi
    rlm-cli
  ];
}
