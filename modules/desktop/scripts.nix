{
  # Small user scripts: focus-or-run, project, rofi launchers.
  den.aspects.desktop-scripts.provides.to-users.homeManager =
    { pkgs, ... }:
    let
      scriptNames = [
        ./_scripts/focus-or-run.nix
        ./_scripts/project.nix
        ./_scripts/rofi-launcher.nix
        ./_scripts/rofi-web-launcher.nix
      ];
    in
    {
      home.packages = map (script: pkgs.callPackage script { }) scriptNames;
    };
}
