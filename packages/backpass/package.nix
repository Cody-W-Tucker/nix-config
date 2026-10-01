{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_24,
  acpx,
  lavish-axi,
}:

buildNpmPackage rec {
  pname = "backpass";
  version = "0.1.31";

  nodejs = nodejs_24; # upstream engines: node >=22.5.0

  src = fetchzip {
    url = "https://registry.npmjs.org/backpass/-/backpass-${version}.tgz";
    hash = "sha256-1UiBQ9Ktj+TQMaL8rVhGLqsaXN6DoDc3sEFeKrNf7gg=";
  };

  npmDepsHash = "sha256-/V4rn7nKzIbBnpm1WpEuVkXFC32cKAPDFI68rcozSN8=";

  # buildNpmPackage needs a resolved lockfile; npmDepsHash verifies it.
  # Lock vendored from the published tarball (`npm install
  # --package-lock-only` inside the unpacked sources) so the fixed-output npm
  # fetch and the offline `npm ci` stay in sync.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  # Backpass shells out to `acpx` and the optional `lavish-axi` review UI
  # resolved from PATH, and its Pi ACP launcher spawns `npx pi-acp@^0.0.33`.
  # Keep all three as private runtime dependencies on the wrapper PATH so
  # `backpass` works with only backpass itself installed.
  postInstall = ''
    wrapProgram $out/bin/backpass \
      --prefix PATH : ${
        lib.makeBinPath [
          acpx
          lavish-axi
          nodejs_24
        ]
      }
  '';

  meta = {
    description = "Gradient descent for agent memory - analyzes past agent session transcripts and proposes evidence-backed edits to AGENTS.md / CLAUDE.md";
    homepage = "https://github.com/kunchenguid/backpass";
    downloadPage = "https://www.npmjs.com/package/backpass";
    license = lib.licenses.mit;
    mainProgram = "backpass";
    platforms = [ "x86_64-linux" ];
  };
}
