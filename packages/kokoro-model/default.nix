{
  runCommand,
  fetchurl,
}:

let
  config = fetchurl {
    url = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/config.json";
    hash = "sha256-WrsB4kA7ByvwPQT94WBEPiCdeg2tSaQjvhUZa5tDwX8=";
    name = "config.json";
  };

  weights = fetchurl {
    url = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/kokoro-v1_0.pth";
    hash = "sha256-SW26EY0aWPXz2y78iNvcIW4Eg/yJ/m5H7h8sU/GK0eQ=";
    name = "kokoro-v1_0.pth";
  };
in
runCommand "kokoro-82m-model" { } ''
  mkdir -p $out
  cp ${config} $out/config.json
  cp ${weights} $out/kokoro-v1_0.pth
''
