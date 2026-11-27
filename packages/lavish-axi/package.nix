{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "lavish-axi";
  version = "0.1.31";

  nodejs = nodejs_24;

  src = fetchzip {
    url = "https://registry.npmjs.org/lavish-axi/-/lavish-axi-${version}.tgz";
    hash = "sha256-sUQoKI7rSXSolxM8MT4lQoTGOPM3HWAsBGJLU9qeBqo=";
  };

  npmDepsHash = "sha256-DPVnG61tS+B3o8G5RR6kyr16VaFWHOiRTEpL6X9jgNY=";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  npmPackFlags = [ "--ignore-scripts" ];

  meta = {
    description = "Review UI for Backpass - HTML artifact editor and collaboration review interface";
    homepage = "https://github.com/kunchenguid/lavish-axi";
    downloadPage = "https://www.npmjs.com/package/lavish-axi";
    license = lib.licenses.mit;
    mainProgram = "lavish-axi";
    platforms = [ "x86_64-linux" ];
  };
}
