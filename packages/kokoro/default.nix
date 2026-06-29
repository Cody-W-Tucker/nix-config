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

  mkVoice =
    name: hash:
    fetchurl {
      url = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/voices/${name}.pt";
      inherit hash;
      name = "${name}.pt";
    };

  voices = {
    # American female (lang_code 'a')
    af_heart = "sha256-CrVwm4/6sZv9hJzRHZj3W2CvdzMlOtDWexI4KhAstP8=";
    af_bella = "sha256-jLZOAvzI3gMnqOE4F+ScdslF7PAFLOrJfTCBSA6OSNY=";
    af_sky = "sha256-x5lUiu0G4MsNZVqFoBtI5/EEhNcWY/mjBFpbk2LoUSw=";
    af_nicole = "sha256-xVYYCLz1JQ/oxfXeMsry2U8n5X6Vvv2wmMXIWZHUxdo=";
    af_alloy = "sha256-bYdxSd2LNI+60S5YRbfkPZdTkOnztoqBHR2GFovvWqM=";
    af_aoede = "sha256-wDvRpMNxbC2Oqj1QAi9i1cMc+9bhWTOgCxf+/hOEHMQ=";

    # American male
    am_adam = "sha256-ztfihKuhJHKJG+HaOrNNuEzAXMArWIlTV5bb8tiwyzQ=";
    am_michael = "sha256-mkQ7eaSyJImlsKt8ZRoLzRowvvZ1woMz8Glxq71HvTc=";

    # British samples (use with lang_code 'b')
    bf_emma = "sha256-0KQj3qv0pStPSTGMUXQsVOIbuJu76aEhQed1jdtdpwE=";
    bm_george = "sha256-8byBIhPcWXdHaeXIAASxPut5vXgTCxGy1/k0VC2rgRs=";
  };
in
runCommand "kokoro" { } ''
  mkdir -p $out
  cp ${config} $out/config.json
  cp ${weights} $out/kokoro-v1_0.pth
  ${builtins.concatStringsSep "\n" (
    builtins.attrValues (
      builtins.mapAttrs (name: hash: ''
        cp ${mkVoice name hash} $out/${name}.pt
      '') voices
    )
  )}
''
