{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Minimal fix for linux-firmware bug on Strix Halo (17f0_11).
  # The upstream npu.sbin.zst symlink points to an empty placeholder.
  # We provide ONLY the fixed files, which take precedence because
  # hardware.firmware uses buildEnv and "first package takes precedence".
  amdnpuStrixHaloFix = pkgs.runCommand "amdnpu-strix-halo-fix" { } ''
    mkdir -p $out/lib/firmware/amdnpu/17f0_11

    # Link the real firmware blob from linux-firmware
    ln -s ${pkgs.linux-firmware}/lib/firmware/amdnpu/17f0_11/npu.sbin.1.1.2.65.zst \
      $out/lib/firmware/amdnpu/17f0_11/npu.sbin.1.1.2.65.zst

    # Create proper symlinks that the driver actually requests
    ln -s npu.sbin.1.1.2.65.zst $out/lib/firmware/amdnpu/17f0_11/npu.sbin.zst
    ln -s npu.sbin.1.1.2.65.zst $out/lib/firmware/amdnpu/17f0_11/npu_7.sbin.zst
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

  # Prepend our minimal fix package FIRST so it takes precedence
  # over the broken upstream linux-firmware symlinks
  hardware.firmware = lib.mkIf (lib.elem "amdxdna" config.boot.kernelModules) [
    amdnpuStrixHaloFix
  ];

  # Add NPU userspace tools when available
  # Currently the main interface is through the kernel driver
  # Future: rocmlir, xrt, or other AMD NPU tools
}
