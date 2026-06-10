{ python313Packages, fetchPypi }:

python313Packages.buildPythonPackage rec {
  pname = "mem0ai";
  version = "2.0.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-DP/b2qlhqkNxxwfl+Q8llhrgzxcBaav2qvatuhTGvKE=";
  };

  nativeBuildInputs = with python313Packages; [
    pythonRelaxDepsHook
  ];

  build-system = with python313Packages; [
    hatchling
  ];

  pythonRelaxDeps = [ "protobuf" ];

  dependencies = with python313Packages; [
    openai
    posthog
    protobuf
    pydantic
    pytz
    qdrant-client
    sqlalchemy
  ];
}
