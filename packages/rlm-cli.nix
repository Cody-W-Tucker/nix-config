{ pkgs, lib }:

pkgs.stdenv.mkDerivation rec {
  pname = "rlm-cli";
  version = "0.4.9";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/rlm-cli/-/rlm-cli-${version}.tgz";
    hash = "sha512-yGU3sSrDVbCFhAy4Po21Dz+JXuMJLNOfxrCabSCg6x21HZjps7whLo6TAlzgmtk+LGDiRfWjtBoMMoDyu98R9g==";
  };

  buildInputs = [
    pkgs.nodejs_20
    pkgs.python3
  ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # No unpack phase needed, we handle it manually
  dontUnpack = false;

  installPhase = ''
    mkdir -p $out/lib/node_modules/rlm-cli

    # Copy all package contents
    cp -r . $out/lib/node_modules/rlm-cli/

    # Create the binary wrapper
    mkdir -p $out/bin

    # Make wrapper that calls node with the script
    makeWrapper ${pkgs.nodejs_20}/bin/node $out/bin/rlm \
      --add-flags "$out/lib/node_modules/rlm-cli/dist/main.js" \
      --prefix PATH : "${pkgs.python3}/bin"
  '';

  meta = with lib; {
    description = "Standalone CLI for Recursive Language Models (RLMs)";
    homepage = "https://github.com/viplismism/rlm-cli";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "rlm";
  };
}
