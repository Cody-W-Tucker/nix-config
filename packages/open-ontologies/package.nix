{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  llvmPackages,
}:

rustPlatform.buildRustPackage {
  pname = "open-ontologies";
  version = "2.1.0-unstable-2026-10-31";

  src = fetchFromGitHub {
    owner = "fabio-rovai";
    repo = "open-ontologies";
    rev = "cefe5997d04553ac495873e8aa1046c1d6b85f7d";
    hash = "sha256-QTT7xdGbrfIH6mSthfEmKAm/WXn5MskORDfEH5WLJUo=";
  };

  cargoHash = "sha256-8LyHFVgraJZzttN3e75U5DOWVqJ0VsnKUGNH9y9L2hA=";

  nativeBuildInputs = [
    pkg-config
    llvmPackages.libclang
  ];
  buildInputs = [ openssl ];
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  # Repository-wide integration tests include Git-checkout and external-tool checks.
  # Keep the unit tests and an MCP integration test in the archive build.
  cargoTestFlags = [
    "--lib"
    "--bins"
    "--test"
    "alignment_evaluation_set_test"
  ];
  preCheck = ''
    export HOME="$TMPDIR"
  '';

  meta = {
    description = "Ontology engine with a CLI and MCP server";
    homepage = "https://github.com/fabio-rovai/open-ontologies";
    license = lib.licenses.mit;
    mainProgram = "open-ontologies";
    platforms = lib.platforms.linux;
  };
}
