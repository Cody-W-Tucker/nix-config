{
  # Shared baseline for every host: system modules, shared feature options, boot/firmware.
  den.aspects.base.nixos.imports = [
    ../../modules/system/base.nix
    ../../modules/hardware/baseline.nix
  ];
}
