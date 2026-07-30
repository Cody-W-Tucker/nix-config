# Shared hardware baseline: boot loader policy and Intel microcode.
# Consumed by every Intel-based host; keep this module free of host-specific
# disk, kernel, swap, or GPU settings.
{
  config,
  lib,
  ...
}:

{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
