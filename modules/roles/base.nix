{
  # Shared baseline for every host: system modules, shared feature options, boot/firmware.
  den.aspects.base.nixos.imports = [
    ../_legacy/system/base.nix
    ../_legacy/hardware/baseline.nix
  ];
}
