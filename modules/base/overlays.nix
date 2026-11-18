{
  # Apply the flake's shared overlay (see overlays/default.nix).
  den.aspects.overlays.nixos =
    { self, ... }:
    {
      nixpkgs.overlays = [ self.overlays.default ];
    };
}
