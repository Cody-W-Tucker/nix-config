{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation {
  pname = "px0";
  version = "0.1.1";

  src = fetchurl {
    url = "https://github.com/px0-ai/px0/releases/download/v0.1.1/px0-0.1.1-linux-amd64";
    hash = "sha256-WK7rY0XP8a2h9DzQgbpAmwqtEI2anTfvY1OdFMp440o=";
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/px0
    runHook postInstall
  '';

  meta = {
    description = "px0 CLI";
    homepage = "https://github.com/px0-ai/px0";
    license = lib.licenses.mit;
    mainProgram = "px0";
    platforms = [ "x86_64-linux" ];
  };
}
