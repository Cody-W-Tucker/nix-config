{ pkgs, ... }:

let
  cuaSrc = pkgs.fetchFromGitHub {
    owner = "trycua";
    repo = "cua";
    rev = "7468487d303469b4993b960c8a2cb66289034bed";
    sha256 = "0gczkv1fj29b5ax7m7hlb35bm10bawnvhlphr5gg8b0n03b1262z";
  };
in
{
  _module.args.hermesCuaDriver = pkgs.callPackage "${cuaSrc}/nix/cua-driver/package.nix" {
    src = "${cuaSrc}/libs/cua-driver/rust";
  };
}
