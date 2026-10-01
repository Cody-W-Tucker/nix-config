{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "no-mistakes";
  version = "1.86.0";

  src = fetchFromGitHub {
    owner = "kunchenguid";
    repo = "no-mistakes";
    rev = "v${version}";
    hash = "sha256-5gLVgewdzwiNP7Xp317YTNPkkWBWiXDF/SxcgOQTxqE=";
  };

  vendorHash = "sha256-maAVBptEtdrGanJHwAPAmuGBorzIMUgK6T+NmIz1kS0=";

  subPackages = [ "cmd/no-mistakes" ];

  # Mirrors upstream `make build` LDFLAGS (internal/buildinfo); Commit/Date
  # are left empty for reproducibility and Telemetry* pin the Makefile
  # defaults so the build behaves like a plain `make build` without .env.
  ldflags = [
    "-X github.com/kunchenguid/no-mistakes/internal/buildinfo.Version=v${version}"
    "-X github.com/kunchenguid/no-mistakes/internal/buildinfo.TelemetryHost=https://a.kunchenguid.com"
    "-X github.com/kunchenguid/no-mistakes/internal/buildinfo.TelemetryWebsiteID=f959e889-92f5-4121-8a1f-571b10861198"
  ];

  # Upstream `make test` runs `go test -race ./...` plus a tagged e2e suite
  # that drives real agent CLIs; both need network access the Nix sandbox
  # does not provide. Same rationale as the upstream treehouse package.nix
  # (doCheck = false).
  doCheck = false;

  meta = {
    description = "Git push gate that runs an AI-driven validation pipeline and opens clean PRs";
    homepage = "https://github.com/kunchenguid/no-mistakes";
    license = lib.licenses.mit;
    mainProgram = "no-mistakes";
    platforms = [ "x86_64-linux" ];
  };
}
