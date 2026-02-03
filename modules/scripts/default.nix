{ pkgs, ... }:

let
  scriptNames = [
    ./rofi-launcher.nix
    ./rofi-web-launcher.nix
    ./rofi-opencode.nix
    ./bluetooth-switch.nix
    ./update.nix
    ./ai-doc-upload.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  # Adding the scripts to the system packages
  environment.systemPackages = scriptPackages;
}
