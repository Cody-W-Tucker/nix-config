# EC-SU_AXB35 embedded controller kernel module for GMKtec EVO-X2
# Provides fan control, power modes, and thermal monitoring
{
  stdenv,
  lib,
  fetchFromGitHub,
  kernel,
}:
let
  ec-su-axb35-src = fetchFromGitHub {
    owner = "cmetz";
    repo = "ec-su_axb35-linux";
    rev = "main";
    sha256 = "sha256-WgOYDmhswxfRF9AbhRKr4B6q/RXrZP6jfKBuCPPZiDw=";
  };
in
stdenv.mkDerivation {
  pname = "ec-su-axb35";
  version = "0.1.0-${kernel.version}";

  src = ec-su-axb35-src;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernel.makeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "M=$(PWD)"
  ];

  buildPhase = ''
    make $makeFlags modules
  '';

  installPhase = ''
    make $makeFlags INSTALL_MOD_PATH=$out modules_install
  '';

  meta = {
    description = "Embedded controller driver for SU_AXB35 (GMKtec EVO-X2)";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
