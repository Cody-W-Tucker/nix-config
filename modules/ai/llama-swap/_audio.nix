# Speech models served through llama-swap by OpenAI-compatible helper servers,
# plus the speech-history service that records Fluid transcriptions.
# CUDA builds of onnxruntime and torch come from the host-wide
# nixpkgs.config.cudaSupport, not from overrides here.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  endpoint = import ./_endpoint.nix;
  user = config.codyos.site.user.name;
  group = "users";

  diarizationEnrollmentDir = "/var/lib/llama-swap/diarization/enrollment";
  # The diarization server hardcodes this path; startup fails with a read-only
  # file system error unless it is created and in ReadWritePaths.
  diarizationEmbeddingCache = "/var/lib/llama-swap/diarization/embedding-cache";
  diarizationCache = "/var/cache/llama-swap/whisperx";
  speechHistoryDir = "/var/lib/llama-swap/speech-history";
  speechHistoryUrl = "http://127.0.0.1:${toString endpoint.speechHistoryPort}";

  # Fluid Speech Pro by FluidVoice (CC BY 4.0). Keep the external weights
  # beside the clean graphs, under the exact filenames embedded in the graphs.
  fluidSpeechProClean =
    let
      rev = "fa588e9f87f1b9ad0ca2e2d8f7eaf84dc3803581";
      fetch =
        name: sha256:
        pkgs.fetchurl {
          url = "https://huggingface.co/FluidVoice-Labs/fluid-speech-pro-onnx/resolve/${rev}/${name}";
          inherit sha256;
        };
    in
    pkgs.linkFarm "fluid-speech-pro-clean-int8" (
      lib.mapAttrs fetch {
        "encoder-model.clean.int8.onnx" =
          "cc9ffaba4d01f3ba4ca276aa7d8b38719266522b426ee093d7f60513823f5b2b";
        "encoder-model.int8.onnx.data" = "d2f8bfbb1fa399f207cde85aa3fabee0d67f6730cb31cbf31832c10de69f9c3c";
        "decoder.clean.int8.onnx" = "38b69847defd184b0b4924d161b70cf9b454a2ba2cdf776226f74acc519a7d84";
        "decoder.int8.onnx.data" = "632c3cbf59d3e52d2f7f4dda3bf8e28c045f7a3bb3dbef0f44529ba63926efaa";
        "joiner.clean.int8.onnx" = "397e03c1de42926dc09a82ad0db3c65de92fb3600141bf5f0ab430a4161962f6";
        "joiner.int8.onnx.data" = "7473427ab99417fae8cf7025ba11507cb5dcc223194bae2f79064dde0936d0af";
        "vocab.txt" = "d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d";
        LICENSE = "9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411";
        NOTICE = "fb46bca8b337792a755ec6c77e0e33ebd27d181f46540e4b88382d179942625c";
      }
    );

  sherpaPython = pkgs.python313.withPackages (
    ps: with ps; [
      fastapi
      numpy
      python-multipart
      sherpa-onnx
      uvicorn
    ]
  );
  kokoroPython = pkgs.python313.withPackages (
    ps: with ps; [
      # Provide the spacy model that misaki's G2P (used by kokoro) requires.
      # Without it in the same env, misaki calls spacy.cli.download which fails
      # in the Nix python env (no pip/uv).
      spacy-models.en_core_web_sm
      fastapi
      kokoro
      numpy
      torch
      uvicorn
    ]
  );
  whisperDiarization = inputs.whisper-diarization.lib.${pkgs.stdenv.hostPlatform.system}.mkPackage {
    python = pkgs.python313.withPackages (
      ps: with ps; [
        fastapi
        python-multipart
        ps.torch
        uvicorn
        whisperx
      ]
    );
  };
  kokoroAssets = pkgs.kokoro-assets;
in
{
  sops.secrets."huggingface-read" = {
    owner = user;
    inherit group;
    mode = "0400";
  };

  services.llama-swap.settings.models = {
    "fluid-speech-pro-clean" = {
      ttl = 0;
      cmd = ''
        ${sherpaPython}/bin/python3 ${./sherpa-onnx-openai-server.py} \
          --host 127.0.0.1 \
          --port ''${PORT} \
          --model-dir ${fluidSpeechProClean} \
          --model-id fluid-speech-pro-clean \
          --provider cuda \
          --num-threads 4 \
          --max-chunk-seconds 30 \
          --ffmpeg ${lib.getExe pkgs.ffmpeg-headless} \
          --history-url ${speechHistoryUrl}
      '';
    };
    "whisper-diarization" = {
      ttl = 0;
      cmd = ''
        env HOME=${diarizationCache} \
        ${whisperDiarization}/bin/whisper-diarization \
          --host 127.0.0.1 \
          --port ''${PORT} \
          --model-id whisper-diarization \
          --device cuda \
          --compute-type float16 \
          --download-root ${diarizationCache} \
          --enrollment-dir ${diarizationEnrollmentDir} \
          --hf-token-path ${config.sops.secrets."huggingface-read".path}
      '';
    };
    "kokoro-82m" = {
      ttl = 30;
      cmd = ''
        ${kokoroPython}/bin/python3 ${./kokoro-openai-server.py} \
          --host 127.0.0.1 \
          --port ''${PORT} \
          --model-id kokoro-82m \
          --lang-code a \
          --default-voice af_heart \
          --voices-dir ${kokoroAssets} \
          --model-path ${kokoroAssets}/kokoro-v1_0.pth \
          --config-path ${kokoroAssets}/config.json
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d ${diarizationCache} 0755 ${user} ${group} - -"
    "d ${diarizationEnrollmentDir} 0750 ${user} ${group} - -"
    "d ${diarizationEmbeddingCache} 0750 ${user} ${group} - -"
    "d ${speechHistoryDir} 0750 ${user} ${group} - -"
    "d ${speechHistoryDir}/audio 0750 ${user} ${group} 30d -"
  ];

  systemd.services.llama-swap.serviceConfig.ReadWritePaths = lib.mkAfter [
    diarizationCache
    diarizationEnrollmentDir
    diarizationEmbeddingCache
  ];

  systemd.services.speech-history = {
    description = "Speech transcript history and vocabulary";
    wantedBy = [ "multi-user.target" ];
    before = [ "llama-swap.service" ];
    serviceConfig = {
      ExecStart = lib.escapeShellArgs [
        (lib.getExe pkgs.python3)
        "${./speech-history.py}"
        "--host"
        "0.0.0.0"
        "--port"
        (toString endpoint.speechHistoryPort)
        "--state-dir"
        speechHistoryDir
        "--common-words"
        "${pkgs.scowl}/share/dict/wamerican.50"
        "--vocabulary"
        "${./_speech-vocabulary.json}"
      ];
      User = user;
      Group = group;
      Restart = "on-failure";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ speechHistoryDir ];
    };
  };
}
