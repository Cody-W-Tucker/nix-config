{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Workaround for linux-firmware bug: The npu.sbin symlink for Strix Halo
  # (17f0_11) points to an empty placeholder file (npu.sbin.1.0.0.166.zst).
  # The actual firmware is in npu.sbin.1.1.2.65.zst.
  fixedAmdnpuFirmware =
    pkgs.runCommand "linux-firmware-amdnpu-fixed"
      {
        nativeBuildInputs = [ pkgs.coreutils ];
      }
      ''
        mkdir -p $out/lib/firmware/amdnpu

        # Copy entire amdnpu directory, following symlinks (copies content, not symlinks)
        cp -rL ${pkgs.linux-firmware}/lib/firmware/amdnpu/* $out/lib/firmware/amdnpu/

        # Fix the broken files for 17f0_11 (Strix Halo)
        # Remove the bad symlinks/files and create correct ones
        if [ -f $out/lib/firmware/amdnpu/17f0_11/npu.sbin.1.1.2.65.zst ]; then
          # Remove the broken placeholder file and symlink
          rm -f $out/lib/firmware/amdnpu/17f0_11/npu.sbin.zst
          rm -f $out/lib/firmware/amdnpu/17f0_11/npu_7.sbin.zst

          # Create proper symlinks pointing to the actual firmware
          ln -s npu.sbin.1.1.2.65.zst $out/lib/firmware/amdnpu/17f0_11/npu.sbin.zst
          ln -s npu.sbin.1.1.2.65.zst $out/lib/firmware/amdnpu/17f0_11/npu_7.sbin.zst
        fi
      '';
in
{
  # AMD XDNA NPU driver configuration for Ryzen AI processors
  # This enables the Neural Processing Unit (NPU) on Strix Halo and other
  # Ryzen AI APUs for AI/ML acceleration.

  # Ensure the amdxdna driver is available
  boot.kernelModules = [ "amdxdna" ];

  # The NPU firmware is included in linux-firmware package
  # Ensure firmware is available early in boot
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  # Override firmware package with fixed AMD NPU firmware
  # This works around the broken npu.sbin symlink in upstream linux-firmware
  hardware.firmware = lib.mkIf (lib.elem "amdxdna" config.boot.kernelModules) [ fixedAmdnpuFirmware ];

  # Add NPU userspace tools when available
  # Currently the main interface is through the kernel driver
  # Future: rocmlir, xrt, or other AMD NPU tools
}
