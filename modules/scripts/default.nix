{ pkgs, ... }:

let
  scriptNames = [
    ./chromecast-stop.nix
    ./project.nix
    ./rofi-chromecast.nix
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
