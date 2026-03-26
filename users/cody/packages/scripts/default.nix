{ pkgs, ... }:

let
  scriptNames = [
    ./focus-or-run.nix
    ./project.nix
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  home.packages = scriptPackages;
}
