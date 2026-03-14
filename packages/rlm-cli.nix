{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_20,
  python3,
}:

buildNpmPackage {
  pname = "rlm-cli";
  version = "0.4.9";

  nodejs = nodejs_20;

  src = fetchFromGitHub {
    owner = "viplismism";
    repo = "rlm-cli";
    rev = "main";
    hash = "sha256-m3TG/gPi8z7zFGRZ2Q59zJkRZo0dw36xfmnYJNFi4Ow=";
  };

  npmDepsHash = "sha256-FCET7aZtEzQ7XWtilJd+6zZ15tS0yN40PQ1mvH3h8XQ=";

  nativeBuildInputs = [ python3 ];

  npmBuildScript = "build";

  postInstall = ''
    # Ensure rlm binary is available
    if [ ! -f $out/bin/rlm ]; then
      ln -s $out/lib/node_modules/rlm-cli/bin/rlm.mjs $out/bin/rlm || \
      ln -s $out/lib/node_modules/rlm-cli/dist/main.js $out/bin/rlm
    fi
  '';

  meta = {
    description = "Standalone CLI for Recursive Language Models (RLMs)";
    homepage = "https://github.com/viplismism/rlm-cli";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "rlm";
  };
}
