{ pkgs, ... }:

let
  scriptNames = [
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./bluetooth-switch.nix
    ./update.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  # Adding the scripts to the system packages
  environment.systemPackages = scriptPackages;
}
