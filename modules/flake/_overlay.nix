{ inputs }:
final: prev:
prev.lib.packagesFromDirectoryRecursive {
  inherit (final) callPackage;
  directory = ../../packages;
}
// {
  unstable =
    if toString prev.path == inputs.nixpkgs-unstable.outPath then
      final
    else
      import inputs.nixpkgs-unstable {
        inherit (prev.stdenv.hostPlatform) system;
        inherit (prev) config;
      };
}
