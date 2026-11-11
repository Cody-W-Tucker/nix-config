# Shared nixpkgs overlay, applied to every host via modules/system/overlays.nix.
#
# Local packages: every packages/<name>/package.nix becomes pkgs.<name>, called
# with the host's own pkgs (so packages can depend on each other by name).
#
# `pkgs.unstable` exposes nixpkgs-unstable for hosts on stable nixpkgs (the NAS).
# It reuses the flake's default-config instance, so it does NOT inherit the
# host's nixpkgs.config (allowUnfree, cudaSupport). Consumers needing unfree or
# CUDA builds instantiate their own (see hosts/nas/models.nix).
{ inputs }:
final: prev:
prev.lib.packagesFromDirectoryRecursive {
  inherit (final) callPackage;
  directory = ../packages;
}
// {
  unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
}
