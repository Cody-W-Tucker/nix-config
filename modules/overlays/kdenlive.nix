{ pkgs, ... }:

let
  srt_equalizer = pkgs.python3Packages.buildPythonPackage rec {
    pname = "srt_equalizer";
    version = "0.1.10";
    pyproject = true;
    src = pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-X2sbLEixK7HKqxOCLX3dClSod3K4JKCqK6ZMAz03k1M=";
    };
    doCheck = false;
    nativeBuildInputs = [ pkgs.python3Packages.poetry-core ];
    propagatedBuildInputs = [ pkgs.python3Packages.srt ];
  };

  customPython = pkgs.python3.withPackages (ps: with ps; [
    pip
    openai-whisper
    srt
    srt_equalizer
    (torch.override { cudaSupport = true; }) # Enable CUDA for GPU
  ]);
in

{
  # Overlay to enable speech recognition in Kdenlive
  nixpkgs.overlays = [
    (final: prev: {
      kdePackages = prev.kdePackages.overrideScope (kfinal: kprev: {
        kdenlive = kprev.kdenlive.overrideAttrs (oldAttrs: {
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];

          postFixup = (oldAttrs.postFixup or "") + ''
            wrapProgram $out/bin/kdenlive \
              --prefix PATH : ${final.lib.makeBinPath [ customPython final.cudaPackages.cudatoolkit ]} \
              --prefix LD_LIBRARY_PATH : ${final.lib.makeLibraryPath [ final.cudaPackages.cudatoolkit final.stdenv.cc.cc.lib ]}
          '';
        });
      });
    })
  ];

  # Machine specific packages
  environment.systemPackages =
    (with pkgs; [
      kdePackages.kdenlive
    ]);
}
