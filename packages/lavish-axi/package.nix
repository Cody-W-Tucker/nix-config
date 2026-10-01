{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "lavish-axi";
  version = "0.1.31";

  nodejs = nodejs_24; # upstream engines: node >=22

  src = fetchzip {
    url = "https://registry.npmjs.org/lavish-axi/-/lavish-axi-${version}.tgz";
    hash = "sha256-sUQoKI7rSXSolxM8MT4lQoTGOPM3HWAsBGJLU9qeBqo=";
  };

  npmDepsHash = "sha256-DPVnG61tS+B3o8G5RR6kyr16VaFWHOiRTEpL6X9jgNY=";

  # Lock generated from the published tarball (`npm install
  # --package-lock-only` inside the unpacked sources) so the fixed-output npm
  # fetch and the offline `npm ci` stay in sync.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true; # dist/ ships prebuilt in the npm tarball

  # `npm pack --dry-run` (used by the install hook to enumerate files) would
  # otherwise run the `prepack` build; the shipped dist/ is used as-is.
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
