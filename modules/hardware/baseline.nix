{ den, ... }:
{
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
      swapDevices = [
        {
          device = "/swapfile";
          size = 32768;
        }
      ];
    };

  den.default.includes = [ den.aspects.hardware-baseline ];
}
