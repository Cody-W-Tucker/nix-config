{ pkgs, ... }:

let
  scriptNames = [
    ./project.nix
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./task-runner.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  home.packages = scriptPackages;
}
