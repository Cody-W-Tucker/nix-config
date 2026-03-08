{
  pkgs,
  ...
}:

let
  scriptNames = [
    ./task-runner.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  home.packages = scriptPackages;
}
