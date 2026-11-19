{
  den.aspects.project.provides.to-users.homeManager = { pkgs, ... }: {
    home.packages = [ (pkgs.callPackage ./_scripts/project.nix { }) ];
  };
}
