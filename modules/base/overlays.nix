{
  # Apply the flake's shared overlay (see modules/flake/_overlay.nix).
  den.aspects.overlays.nixos =
    { self, ... }:
    {
      nixpkgs.overlays = [ self.overlays.default ];
    };
}
