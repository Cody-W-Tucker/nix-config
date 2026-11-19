{ den, ... }:
{
  # Shared hardware baseline: boot loader policy, redistributable firmware, Intel
  # microcode, and swap policy.
  # Consumed by every Intel-based host; keep this module free of host-specific
  # disk, kernel, or GPU settings.
  den.aspects.hardware-baseline.nixos =
    { config, lib, ... }:
    {
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      hardware.enableRedistributableFirmware = true;
      services.fwupd.enable = true;
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      # 32GB swap file to avoid OOM killer on low-memory workloads.
      swapDevices = [
        {
          device = "/swapfile";
          size = 32768;
        }
      ];
    };

  den.default.includes = [ den.aspects.hardware-baseline ];
}
