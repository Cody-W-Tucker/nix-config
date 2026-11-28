{ inputs, ... }:
let
  pkgs = import ./_pkgs.nix { inherit inputs; };
in
{
  flake = {
    overlays.default = import ./_overlay.nix { inherit inputs; };
    formatter.x86_64-linux = pkgs.nixfmt-tree;
    packages.x86_64-linux = builtins.mapAttrs (name: _: pkgs.${name}) (
      pkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../../packages)
    );
  };
}
