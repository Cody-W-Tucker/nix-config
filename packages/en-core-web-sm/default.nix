{
  fetchurl,
  pythonPkgs ? null,
  python313Packages ? null,
}:

# Used upstream in the text-to-speech stack

let
  py = if pythonPkgs != null then pythonPkgs else python313Packages;
in
py.buildPythonPackage {
  pname = "en-core-web-sm";
  version = "3.8.0";
  format = "wheel";

  src = fetchurl {
    url = "https://github.com/explosion/spacy-models/releases/download/en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl";
    hash = "sha256-GTJCnbcn1L/z3u1rNM/AXfF3lPSlLusmz4ko98Gg+4U=";
  };

  propagatedBuildInputs = with py; [
    spacy
  ];

  pythonImportsCheck = [ "en_core_web_sm" ];
}
