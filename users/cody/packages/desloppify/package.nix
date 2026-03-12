{ pkgs }:

pkgs.python3Packages.buildPythonPackage rec {
  pname = "desloppify";
  version = "0.9.5";
  pyproject = true;
  nativeBuildInputs = [
    pkgs.python3Packages.setuptools
    pkgs.python3Packages.defusedxml
  ];
  src = pkgs.fetchPypi {
    inherit pname version;
    sha256 = "sha256-GXaPK0eS38787I5hwsHZ10eSdtI9hLQKyIkeM3OS884=";
  };
}
