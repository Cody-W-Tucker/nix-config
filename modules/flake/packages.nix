# Every packages/<name>/ directory, as built by the shared overlay.
{ inputs, ... }:
let
  pkgs = import ./_pkgs.nix { inherit inputs; };
in
{
  flake.packages.x86_64-linux = builtins.mapAttrs (name: _: pkgs.${name}) (
    pkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../packages)
  );
}
