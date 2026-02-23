{ pkgs, ... }:

let
  scriptNames = [
    ./ai-doc-upload.nix
    ./bluetooth-switch.nix
    ./project.nix
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./update.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  # Adding the scripts to the system packages
  environment.systemPackages = scriptPackages;
}
