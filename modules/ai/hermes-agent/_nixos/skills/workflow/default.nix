{ inputs, pkgs, ... }:
let
  inherit (inputs.workflow.packages.${pkgs.stdenv.hostPlatform.system}) workflowCli;
  skill = "${inputs.workflow}/skills/operational/verified-work-run";
in
{
  services.hermes-agent.extraPackages = [ workflowCli ];

  codyos.hermes-agent.skills.skillPacks = [
    {
      name = "workflow";
      root = pkgs.linkFarm "hermes-workflow-skills" { "operational/verified-work-run" = skill; };
      mode = "managed";
    }
  ];
}
