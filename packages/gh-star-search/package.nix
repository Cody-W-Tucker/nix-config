{
  lib,
  buildGoModule,
  duckdb,
  fetchFromGitHub,
  makeWrapper,
  perl,
  uv,
}:

buildGoModule rec {
  pname = "gh-star-search";
  version = "0-unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "KyleKing";
    repo = "gh-star-search";
    rev = "main";
    hash = "sha256-00ZW/ifDA/2DBK+jzSB15l4mQ54JL46aitKqyy8dtvk=";
  };

  vendorHash = "sha256-KhZgPVBn9x7YfBw9Kh0oVzF+Yxlxp7FeBPjd5zSQKjM=";

  postPatch = ''
    perl -0pi -e 's@repo := &DuckDBRepository\{@if _, err := db.ExecContext(ctx, "LOAD fts"); err != nil {\n\tif _, installErr := db.ExecContext(ctx, "INSTALL fts"); installErr != nil {\n\t\treturn nil, fmt.Errorf("failed to install fts extension: %w", installErr)\n\t}\n\n\tif _, loadErr := db.ExecContext(ctx, "LOAD fts"); loadErr != nil {\n\t\treturn nil, fmt.Errorf("failed to load fts extension: %w", loadErr)\n\t}\n}\n\nrepo := &DuckDBRepository{@' internal/storage/duckdb.go
  '';

  subPackages = [
    "cmd/gh-start-search"
  ];

  nativeBuildInputs = [
    makeWrapper
    perl
  ];

  buildInputs = [
    duckdb
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  postInstall = ''
    if [ -x "$out/bin/gh-start-search" ]; then
      mv "$out/bin/gh-start-search" "$out/bin/gh-star-search"
    fi

    wrapProgram "$out/bin/gh-star-search" \
      --prefix PATH : ${lib.makeBinPath [ uv ]}
  '';

  meta = {
    description = "GitHub CLI extension to search your starred repositories";
    homepage = "https://github.com/KyleKing/gh-star-search";
    license = lib.licenses.mit;
    mainProgram = "gh-star-search";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
