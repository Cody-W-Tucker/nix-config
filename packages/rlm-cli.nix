{ pkgs, lib }:

pkgs.buildNpmPackage rec {
  pname = "rlm-cli";
  version = "0.4.9";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/rlm-cli/-/rlm-cli-${version}.tgz";
    hash = "sha512-yGU3sSrDVbCFhAy4Po21Dz+JXuMJLNOfxrCabSCg6x21HZjps7whLo6TAlzgmtk+LGDiRfWjtBoMMoDyu98R9g==";
  };

  buildInputs = [ pkgs.python3 ];

  nativeBuildInputs = [ pkgs.python3 ];

  # The package is already built in the npm registry
  dontBuild = true;

  # Install phase for pre-built npm packages
  installPhase = ''
    mkdir -p $out/lib/node_modules/rlm-cli
    cp -r . $out/lib/node_modules/rlm-cli/

    # Create the binary wrapper
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/rlm-cli/dist/main.js $out/bin/rlm
    chmod +x $out/bin/rlm

    # Patch shebang to use the Node.js from nixpkgs
    substituteInPlace $out/lib/node_modules/rlm-cli/dist/main.js \
      --replace-fail "#!/usr/bin/env node" "#!${pkgs.nodejs_20}/bin/node"
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
