{ pkgs }:

let
  acpx = pkgs.callPackage ../acpx { };
  lavish-axi = pkgs.callPackage ../lavish-axi { };
in
pkgs.callPackage ./package.nix { inherit acpx lavish-axi; }
