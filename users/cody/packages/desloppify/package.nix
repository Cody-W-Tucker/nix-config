{ pkgs }:

pkgs.python3Packages.buildPythonPackage rec {
  pname = "desloppify";
  version = "0.9.9";
  pyproject = true;
  nativeBuildInputs = [
    pkgs.python3Packages.setuptools
    pkgs.python3Packages.defusedxml
  ];
  src = pkgs.fetchPypi {
    inherit pname version;
    sha256 = "sha256-KbGEJ1U06mAM5vGfNxc9qa514ZFT7lUvuARMyrbs+J0=";
  };
}
