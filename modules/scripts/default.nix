{ pkgs, config, lib, ... }:

let
  scriptNames = [
    ./rofi-launcher.nix
    ./media-player.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  environment.systemPackages = with pkgs; [
    # Adding the scripts to the system packages
  ] ++ scriptPackages;

}
