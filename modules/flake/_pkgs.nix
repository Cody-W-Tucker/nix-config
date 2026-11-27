{ inputs }:
import inputs.nixpkgs-unstable {
  system = "x86_64-linux";
  overlays = [ inputs.self.overlays.default ];
}
