# nixpkgs-unstable with the shared overlay; used by the flake's own outputs
# (packages, checks, formatter) for x86_64-linux.
{ inputs }:
import inputs.nixpkgs-unstable {
  system = "x86_64-linux";
  overlays = [ inputs.self.overlays.default ];
}
