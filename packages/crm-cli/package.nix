{
  lib,
  stdenv,
  fetchzip,
  bun,
  makeWrapper,
  cacert,
}:

let
  version = "0.3.10";
  src = fetchzip {
    url = "https://github.com/dzhng/crm.cli/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-JPFCA9Mz0zu3fg4+Y+8zr3wuUPeapOiHtv5MpyUJcW0=";
  };

  bunDeps = stdenv.mkDerivation {
    pname = "crm-cli-bun-deps";
    inherit version src;
    nativeBuildInputs = [
      bun
      cacert
    ];
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;
    dontFixup = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      bun install --frozen-lockfile --ignore-scripts
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a node_modules $out/
      runHook postInstall
    '';
    outputHashMode = "nar";
    outputHashAlgo = "sha256";
    outputHash = "sha256-U/dXDXVx4d/dmx+HYmoBakgZQkRJjO2pBL7i1kMrKd4=";
  };
in
stdenv.mkDerivation {
  pname = "crm-cli";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/crm-cli
    cp -a . $out/lib/crm-cli/
    rm -rf $out/lib/crm-cli/node_modules
    cp -a ${bunDeps}/node_modules $out/lib/crm-cli/
    makeWrapper ${lib.getExe bun} $out/bin/crm \
      --add-flags "run --silent $out/lib/crm-cli/src/cli.ts"
    runHook postInstall
  '';

  meta = {
    description = "Headless CLI CRM (contacts, deals, pipeline) for agents";
    homepage = "https://github.com/dzhng/crm.cli";
    license = lib.licenses.mit;
    mainProgram = "crm";
    platforms = [ "x86_64-linux" ];
  };
}
