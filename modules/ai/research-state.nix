{ den, inputs, ... }:
let
  package = pkgs: (import "${inputs.workflow}/packages.nix" { inherit pkgs; }).researchState;
in
{
  den.aspects.research-state = {
    nixos = { pkgs, ... }: { environment.systemPackages = [ (package pkgs) ]; };
    homeManager.codyos.harness.skills.research-state = ../../skills/research/research-state;
  };

  den.default.includes = [ den.aspects.research-state ];
}
