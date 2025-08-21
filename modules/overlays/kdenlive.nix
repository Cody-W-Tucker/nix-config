{ pkgs, ... }:

{
  # Overlay to enable speech recognition in Kdenlive with CUDA support
  nixpkgs.overlays = [
    (final: prev: rec {
      myPython = prev.python3.override {
        packageOverrides = pyself: pysuper: {
          srt_equalizer = pysuper.buildPythonPackage rec {
            pname = "srt_equalizer";
            version = "0.1.10";
            pyproject = true;
            src = prev.fetchPypi {
              inherit pname version;
              sha256 = "sha256-X2sbLEixK7HKqxOCLX3dClSod3K4JKCqK6ZMAz03k1M=";
            };
            doCheck = false;
            nativeBuildInputs = [ pysuper.poetry-core ];
            propagatedBuildInputs = [ pysuper.srt ];
          };
          torch = pysuper.torch-bin; # Use prebuilt binary with CUDA support to avoid building from source
        };
      };
      customPython = myPython.withPackages (ps: with ps; [
        pip
        openai-whisper
        srt
        srt_equalizer
        torch
      ]);
      kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
        kdenlive = kprev.kdenlive.overrideAttrs (oldAttrs: {
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
          postFixup = (oldAttrs.postFixup or "") + ''
            wrapProgram $out/bin/kdenlive \
              --prefix PATH : ${final.lib.makeBinPath [ customPython final.cudaPackages.cudatoolkit ]} \
              --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath [ final.cudaPackages.cudatoolkit final.cudaPackages.cudnn final.cudaPackages.libcublas final.stdenv.cc.cc.lib ]}
          '';
        });
      });
    })
  ];

  # Machine specific packages
  environment.systemPackages = with pkgs; [
    kdePackages.kdenlive
  ];
}
