{
  # Pure enable gates for opt-in features whose option modules modules/_legacy/system/base.nix
  # imports everywhere (they stay inert until a host includes the aspect).
  # Option-carrying features (codyos.hardware.nvidia.*) stay as codyos.* settings in the host
  # files. Services under modules/services/ are native aspects without enable options.
  den.aspects.gaming.nixos.codyos.gaming.enable = true;
  den.aspects.openrazer.nixos.codyos.hardware.openrazer.enable = true;
}
