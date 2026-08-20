{
  pkgs,
  lib,
  inputs,
}:

# Packages the PYTHIA oracle *engine* only (the FastAPI app in engine/),
# not the dev launcher (run-all.sh) or the Osiris UI overlay. Source is the
# pinned upstream flake input `inputs.pythia`.
#
# One source patch: config.py hardcodes the runs dir to <repo>/runs, which is
# read-only in the Nix store. We make it honor PYTHIA_RUNS_DIR so the systemd
# service can persist ledger/swarm/watchlist state under /var/lib/pythia.
let
  python = pkgs.python3;
in
python.pkgs.buildPythonPackage rec {
  pname = "pythia-engine";
  version = "0.1.0";

  # `flake = false` input → a plain source tree we hand to buildPythonPackage.
  src = inputs.pythia;

  format = "other";
  dontBuild = true;

  # Make an unset OSIRIS_URL mean "Osiris disabled" (not localhost:3000), and let
  # an empty/disabled URL short-circuit the intake so the engine never attempts a
  # connection. See osiris-disable.patch + the osirisUrl module option docs.
  patches = [ ./osiris-disable.patch ];

  propagatedBuildInputs =
    with python.pkgs;
    [
      fastapi
      uvicorn
      uvloop
      httptools
      websockets
      python-multipart
      httpx
      python-dotenv
      pydantic
    ]
    ++ lib.optional (python.pkgs ? mcp) python.pkgs.mcp;

  postPatch = ''
    substituteInPlace engine/config.py \
      --replace 'runs_dir: Path = _ROOT / "runs"' \
                 'runs_dir: Path = Path(os.environ.get("PYTHIA_RUNS_DIR", str(_ROOT / "runs")))' \
      --replace 'os.environ.get("OSIRIS_URL", "http://localhost:3000")' \
                'os.environ.get("OSIRIS_URL", "")'
  '';

  installPhase = ''
    mkdir -p "$out/${python.sitePackages}"
    cp -r engine "$out/${python.sitePackages}/engine"
  '';

  doCheck = false;

  meta = with lib; {
    description = "PYTHIA oracle engine (FastAPI) — local world-watching prediction oracle";
    homepage = "https://github.com/jangles-byte/Pythia";
    license = licenses.mit;
  };
}
