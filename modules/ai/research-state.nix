{ den, inputs, ... }:
let
  skill = "${inputs.self}/skills/research/research-state";
  package = pkgs: (import "${inputs.workflow}/packages.nix" { inherit pkgs; }).researchState;
in
{
  den.aspects.research-state = {
    nixos = { pkgs, ... }: { environment.systemPackages = [ (package pkgs) ]; };
    homeManager.codyos.harness.skills.research-state = skill;
  };

  den.default.includes = [ den.aspects.research-state ];
}
