{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  llmPkgs = inputs.llm-agents.packages.${system};
in
{
  services.hermes-agent.extraPackages = [ llmPkgs.qmd ];

  codyos.hermes-agent.skillDirs = [ ./. ];
}
