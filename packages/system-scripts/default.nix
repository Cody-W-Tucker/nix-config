{ pkgs, ... }:

# System-wide scripts (installed to environment.systemPackages)
# For user-specific scripts, see users/*/packages/scripts/

let
  scriptNames = [
    ./check-imports.nix
    ./pull-update.nix
    ./update.nix
  ];

  scriptPackages = map (script: pkgs.callPackage (toString script) { inherit pkgs; }) scriptNames;
in

{
  # Adding the scripts to the system packages
  environment.systemPackages = scriptPackages ++ [ pkgs.otel-cli ];
}
