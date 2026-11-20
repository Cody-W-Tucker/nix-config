{ inputs, pkgs, ... }:
let
  inherit (inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}) gnhf no-mistakes;
in
{
  home.packages = [
    gnhf
    no-mistakes
  ];

  codyos.harness.skills = {
    gnhf = "${gnhf}/lib/node_modules/gnhf/skills/gnhf";
    no-mistakes = "${no-mistakes.src}/skills/no-mistakes";
  };
}
