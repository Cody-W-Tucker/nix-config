{ den, inputs, ... }:
let
  skill = "${inputs.self}/skills/research/research-state";
  package = pkgs: (import "${inputs.workflow}/packages.nix" { inherit pkgs; }).researchState;
in
{
  den.aspects.research-state = {
    nixos = { pkgs, ... }: { environment.systemPackages = [ (package pkgs) ]; };
    homeManager.codyos.harness.skills.research-state = skill;

    hermes.provides.to-users.homeManager =
      { pkgs, ... }:
      {
        services.hermes-agent.extraPackages = [ (package pkgs) ];
        codyos.hermes-agent.skills.skillPacks = [
          {
            name = "knowledge-tools";
            root = pkgs.linkFarm "hermes-agent-knowledge-skills" {
              "research/research-state" = skill;
            };
            mode = "managed";
          }
        ];
      };
  };

  den.default.includes = [ den.aspects.research-state ];
}
