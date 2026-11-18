{
  # Pure enable gates for opt-in features (modules/system/base.nix imports the option
  # modules everywhere; they stay inert until a host includes the aspect).
  # Option-carrying features (codyos.hardware.nvidia.*) and docker (also enabled by
  # modules/nas) stay as codyos.* settings in the host files.
  den.aspects.gaming.nixos.codyos.gaming.enable = true;
  den.aspects.openrazer.nixos.codyos.hardware.openrazer.enable = true;
  den.aspects.paperless-scanning.nixos.codyos.paperless-scanning.enable = true;
  den.aspects.hindsight.nixos.codyos.hindsight.enable = true;
  # Web server for opencode.
  den.aspects.opencode.nixos.codyos.opencode.enable = true;
}
