{
  lib,
  unstable,
  # Serving stays on CPU; the training job opts into CUDA.
  cudaSupport ? false,
}:

let
  basePkgs =
    if cudaSupport == (unstable.config.cudaSupport or false) then
      unstable
    else
      import unstable.path {
        inherit (unstable.stdenv.hostPlatform) system;
        config = unstable.config // {
          inherit cudaSupport;
        };
      };
  python = basePkgs.python3.override {
    packageOverrides = self: super: {
      laya = self.buildPythonPackage rec {
        pname = "laya";
        version = "0.5.3";
        format = "pyproject";

        src = self.fetchPypi {
          inherit pname version;
          hash = "sha256-DmguF8dbtpUKO3fXq4cqTvv9sdAzIajsFZR1Inbw6Mo=";
        };

        nativeBuildInputs = [ self.setuptools ];
        propagatedBuildInputs = with self; [
          cryptography
          huggingface-hub
          numpy
          safetensors
          torch
          transformers
          vegaml
        ];

        pythonImportsCheck = [ "laya" ];
        doCheck = false;
      };

      vegaml = self.buildPythonPackage rec {
        pname = "vegaml";
        version = "0.19.0";
        format = "pyproject";

        src = self.fetchPypi {
          inherit pname version;
          hash = "sha256-g7tDXOtuyJs/W8iHNxsQxXEo4zQ+1xiTif4vBPZiF5o=";
        };

        nativeBuildInputs = [ self.setuptools ];
        propagatedBuildInputs = with self; [
          cryptography
          huggingface-hub
          numpy
          safetensors
          torch
          transformers
        ];

        pythonImportsCheck = [ "vegaml" ];
        doCheck = false;
      };
    };
  };
in
python.withPackages (ps: [
  ps.laya
  ps.vegaml
])
