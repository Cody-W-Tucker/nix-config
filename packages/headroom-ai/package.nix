{ pkgs }:

let
  pythonPackages = pkgs.python3Packages;
in
pythonPackages.buildPythonPackage rec {
  pname = "headroom-ai";
  version = "0.4.0";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "headroom_ai";
    inherit version;
    hash = "sha256-H3JeOyGhGKarlnLWpmusyaEsWxl6g5P8zordTpdYIfM=";
  };

  nativeBuildInputs = with pythonPackages; [
    hatchling
    editables
  ];

  propagatedBuildInputs = with pythonPackages; [
    accelerate
    anthropic
    boto3
    click
    datasets
    fastapi
    h2
    hnswlib
    httpx
    jinja2
    litellm
    openai
    pillow
    protobuf
    pydantic
    rich
    sentence-transformers
    sentencepiece
    sqlite-vec
    tiktoken
    tree-sitter-language-pack
    uvicorn
  ];

  nativeCheckInputs = with pythonPackages; [
    pytestCheckHook
  ];

  doCheck = false;

  disabledTests = [
    "test_import"
  ];

  pythonImportsCheck = [
    "headroom"
    "headroom.cli"
  ];

  meta = with pkgs.lib; {
    description = "Context optimization layer for LLM applications";
    homepage = "https://github.com/chopratejas/headroom";
    license = licenses.asl20;
    mainProgram = "headroom";
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
