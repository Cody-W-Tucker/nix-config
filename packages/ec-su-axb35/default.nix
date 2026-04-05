# EC-SU_AXB35 embedded controller kernel module for GMKtec EVO-X2
# Provides fan control, power modes, and thermal monitoring
{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
  kernelPackages,
  pkgs,
}:
let
  ec-su-axb35-src = fetchFromGitHub {
    owner = "cmetz";
    repo = "ec-su_axb35-linux";
    rev = "main";
    sha256 = "sha256-ESXL5o75ESxm1h6N4OiBFcZzoQNEkxP1cY6wEk5UdNc=";
  };

  kernelModule = stdenv.mkDerivation {
    pname = "ec-su-axb35";
    version = "0.1.0-${kernel.version}";

    src = ec-su-axb35-src;

    nativeBuildInputs = kernel.moduleBuildDependencies;

    # Override KERNEL_BUILD to point to our kernel
    makeFlags = kernelPackages.kernelModuleMakeFlags ++ [
      "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
      "INSTALL_MOD_PATH=$(out)"
    ];

    # Build targets from upstream Makefile
    buildFlags = [ "modules" ];
    installTargets = [ "modules_install" ];

    # Don't fixup ELF files
    dontFixup = true;

    meta = {
      description = "Embedded controller driver for SU_AXB35 (GMKtec EVO-X2)";
      license = lib.licenses.gpl2Only;
      platforms = lib.platforms.linux;
    };
  };

  monitor = pkgs.callPackage ./monitor.nix { };
in
{
  inherit kernelModule monitor;
}
