{ pkgs, ... }:

let
  scriptNames = [
    ./focus-or-run.nix
    ./project.nix
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
  ];

  scriptPackages = map (script: pkgs.callPackage script { }) scriptNames;
in

{
  home.packages = scriptPackages;
}
