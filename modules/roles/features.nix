{
  # Pure enable gates for opt-in desktop features whose option modules
  # modules/base/base.nix imports everywhere (they stay inert until a host includes the
  # aspect). Both move into modules/desktop/ with the desktop slice.
  # Services under modules/services/ and hardware under modules/hardware/ are native
  # aspects without enable options.
  den.aspects.gaming.nixos.codyos.gaming.enable = true;
  den.aspects.openrazer.nixos.codyos.hardware.openrazer.enable = true;
}
