{ pkgs }:

let
  pythonPackages = pkgs.python3Packages;
in
pythonPackages.buildPythonPackage rec {
  pname = "headroom-ai";
  version = "0.4.1";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "headroom_ai";
    inherit version;
    hash = "sha256-B868sp3Qtdf9dzl7wzKtsrymG5GWMK2Zpz4Gh2g1vIo=";
  };

  # NOTE: semantic-router is listed in pyproject.toml but is not actually imported anywhere
  # in the headroom source code. The upstream package metadata is stale. This causes the
  # nixpkgs pythonRuntimeDepsCheckHook to fail because semantic-router is not available
  # in nixpkgs and cannot be easily packaged due to complex dependency chains.
  #
  # When upstream releases a new version:
  # 1. Check if semantic-router has been removed from pyproject.toml dependencies
  # 2. If removed, delete this postPatch block entirely
  # 3. If still present but actually used in the codebase, you'll need to package
  #    semantic-router and add it to propagatedBuildInputs instead of patching it out
  # 4. Verify by searching the unpacked source: rg -n "semantic_router|from semantic" .
  postPatch = ''
        substituteInPlace pyproject.toml \
          --replace-fail '    "semantic-router>=0.1.12",' ""

        python <<'PY'
    from pathlib import Path

    path = Path("headroom/cli/proxy.py")
    text = path.read_text()

    text = text.replace(
        '@click.option("--port", "-p", default=8787, type=int, help="Port to bind to (default: 8787)")\n@click.option("--no-optimize", is_flag=True, help="Disable optimization (passthrough mode)")',
        '@click.option("--port", "-p", default=8787, type=int, help="Port to bind to (default: 8787)")\n@click.option(\n    "--openai-api-url",\n    envvar="OPENAI_TARGET_API_URL",\n    default=None,\n    help="Custom OpenAI-compatible upstream URL",\n)\n@click.option("--no-optimize", is_flag=True, help="Disable optimization (passthrough mode)")',
    )

    text = text.replace(
        '    host: str,\n    port: int,\n    no_optimize: bool,',
        '    host: str,\n    port: int,\n    openai_api_url: str | None,\n    no_optimize: bool,',
    )

    text = text.replace(
        '        host=host,\n        port=port,\n        optimize=not no_optimize,',
        '        host=host,\n        port=port,\n        openai_api_url=openai_api_url,\n        optimize=not no_optimize,',
    )

    path.write_text(text)
    PY
  '';

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
