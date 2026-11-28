{ den, ... }:
{
  den.aspects = {
    beast.includes = [ den.aspects.project ];

    project.provides.to-users.homeManager =
      { pkgs, ... }:
      {
        home.packages = [ (pkgs.callPackage ./_scripts/project.nix { }) ];
      };
  };
}
