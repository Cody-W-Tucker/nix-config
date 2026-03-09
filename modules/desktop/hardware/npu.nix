{
  config,
  lib,
  pkgs,
  ...
}:

{
  # AMD XDNA NPU driver configuration for Ryzen AI processors
  # This enables the Neural Processing Unit (NPU) on Strix Halo and other
  # Ryzen AI APUs for AI/ML acceleration.

  # Ensure the amdxdna driver is available
  boot.kernelModules = [ "amdxdna" ];

  # The NPU firmware is included in linux-firmware package
  # Ensure firmware is available early in boot
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # Add NPU userspace tools when available
  # Currently the main interface is through the kernel driver
  # Future: rocmlir, xrt, or other AMD NPU tools
}
