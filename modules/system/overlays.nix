# Apply the flake's shared overlay (see overlays/default.nix).

{ self, ... }:

{
  nixpkgs.overlays = [ self.overlays.default ];
}
