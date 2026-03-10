{ pkgs, ... }:

# System-wide scripts - for user scripts, see users/*/packages/scripts/

let
  scriptNames = [
    ./check-imports.nix
    ./update.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  # Adding the scripts to the system packages
  environment.systemPackages = scriptPackages;
}
