{
  fetchPypi,
  pythonPkgs ? null,
  python313Packages ? null,
}:

let
  py = if pythonPkgs != null then pythonPkgs else python313Packages;
in
py.buildPythonPackage rec {
  pname = "mem0ai";
  version = "2.0.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-DP/b2qlhqkNxxwfl+Q8llhrgzxcBaav2qvatuhTGvKE=";
  };

  nativeBuildInputs = with py; [
    pythonRelaxDepsHook
  ];

  build-system = with py; [
    hatchling
  ];

  pythonRelaxDeps = [ "protobuf" ];

  dependencies = with py; [
    openai
    posthog
    protobuf
    pydantic
    pytz
    qdrant-client
    sqlalchemy
  ];
}
