# Shared nixpkgs overlay, applied to every host via modules/system/overlays.nix.
#
# Local packages: every packages/<name>/package.nix becomes pkgs.<name>, called
# with the host's own pkgs (so packages can depend on each other by name).
#
# `pkgs.unstable` exposes nixpkgs-unstable for hosts on stable nixpkgs (the NAS).
# It is built with the host's own nixpkgs.config (allowUnfree, cudaSupport), so
# consumers never need a separate nixpkgs import for unfree or CUDA builds.
{ inputs }:
final: prev:
prev.lib.packagesFromDirectoryRecursive {
  inherit (final) callPackage;
  directory = ../packages;
}
// {
  unstable = import inputs.nixpkgs-unstable {
    inherit (prev.stdenv.hostPlatform) system;
    inherit (prev) config;
  };
}
