{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Keep the faster-whisper weights in the llama-swap service cache
  # so Open WebUI STT and whisp-away reuse one model download.
  sharedFasterWhisperCache = "/var/cache/llama-swap/faster-whisper";
  kokoroAssets = pkgs.callPackage ../../packages/kokoro { };

  whisperPython = pkgs.python313.withPackages (
    ps: with ps; [
      fastapi
      faster-whisper
      python-multipart
      uvicorn
    ]
  );

  kokoroPython =
    let
      # Kokoro (and future torch-based audio models) need a CUDA-enabled torch
      # for GPU inference. The base python313Packages.torch is CPU-only.
      torchWithCuda = pkgs.python313Packages.torch.override {
        cudaSupport = true;
      };
    in
    pkgs.python313.withPackages (
      ps: with ps; [
        # Provide the spacy model that misaki's G2P (used by kokoro) requires.
        # Without it in the same env, misaki calls spacy.cli.download which fails
        # in the Nix python env (no pip/uv).
        (pkgs.callPackage ../../packages/en-core-web-sm { pythonPkgs = ps; })
        fastapi
        kokoro
        numpy
        torchWithCuda
        uvicorn
      ]
    );

  # WhisperX diarization server: speech-to-text with speaker labels.
  # Uses WhisperX for transcription + alignment and pyannote for diarization.
  # Both require CUDA for acceptable latency on the RTX 3070.
  #
  # Override the entire Python 3.13 package set so torch carries CUDA by default.
  # This avoids the collision where stock whisperx propagates CPU torch while an
  # explicit CUDA torch is also present in withPackages.
  whisperDiarizePython =
    let
      whisperDiarizeScope = pkgs.python313.override {
        packageOverrides = final: prev: {
          torch = prev.torch.override { cudaSupport = true; };
        };
      };
    in
    whisperDiarizeScope.withPackages (
      ps: with ps; [
        fastapi
        python-multipart
        ps.torch
        uvicorn
        whisperx
      ]
    );

  # Persistent paths for diarization enrollment and model cache.
  diarizationEnrollmentDir = "/var/lib/llama-swap/diarization/enrollment";
  diarizationCache = "/var/cache/llama-swap/whisperx";
in
{
  sops.secrets."huggingface-read" = {
    owner = "codyt";
    group = "users";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d ${sharedFasterWhisperCache} 0755 codyt users - -"
    "d ${diarizationCache} 0755 codyt users - -"
    "d ${diarizationEnrollmentDir} 0750 codyt users - -"
  ];

  services.llama-swap = {
    enable = true;
    acceleration = "cuda";
    port = 8081;
    modelOwner = "codyt";
    modelGroup = "users";
    serviceEnvironment = {
      # Wrapper processes still need a writable private cache for other
      # Hugging Face assets such as SpeechT5 TTS files.
      HF_HOME = "/var/cache/llama-swap/huggingface";
      XDG_CACHE_HOME = "/var/cache/llama-swap";
      LD_LIBRARY_PATH = lib.concatStringsSep ":" [
        "/run/opengl-driver/lib"
        "/run/current-system/sw/lib"
      ];
    };
    enabledModels = [
      "qwen3.5-0.8b"
      "qwen3.5-4b"
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      "whisper-medium"
      "whisper-diarization"
      "kokoro-82m"
    ];
    preloadModels = [ "whisper-medium" ];
    settings.groups = {
      audio-stack = {
        swap = false;
        exclusive = false;
        persistent = false;
        members = [
          "whisper-medium"
          "whisper-diarization"
          "kokoro-82m"
        ];
      };
    };
    modelOverrides = {
      # qwen3.5-4b is used by Karakeep for summarization. Disable reasoning so
      # the <think> trace does not consume the context budget.
      "qwen3.5-4b" = {
        contextSize = 32768;
        ttl = 60;
        extraArgs = [
          "--reasoning"
          "off"
        ];
      };
      "qwen3.5-0.8b" = {
        extraArgs = [
          "--reasoning"
          "off"
          "--parallel"
          "2"
        ];
      };
      # Embeddings traffic here is short-form; use a smaller KV/cache footprint and
      # avoid flash-attn to reduce startup instability in llama-server.
      "qwen3-embedding-0.6b" = {
        contextSize = 8192;
        batchSize = 1024;
        ubatchSize = 512;
        flashAttention = false;
      };
      # OCR prefers deterministic decoding. Allow a small amount of request
      # parallelism, but keep batching modest on the 3070 now that this host
      # uses the larger F16 weights.
      "glm-ocr-f16" = {
        batchSize = 1024;
        ubatchSize = 512;
        extraArgs = [
          "--parallel"
          "2"
          "--samplers"
          "top_k"
          "--top-k"
          "1"
          "--temp"
          "0"
        ];
      };
      "whisper-medium" = {
        ttl = 0; # Keep STT warm until another group explicitly evicts it.
        upstream = {
          cmd = ''
            ${whisperPython}/bin/python3 ${../../modules/services/llama-swap/faster-whisper-openai-server.py} \
              --host 127.0.0.1 \
              --port ''${PORT} \
              --model medium.en \
              --model-id whisper-medium \
              --device cuda \
              --compute-type int8 \
              --download-root ${sharedFasterWhisperCache} \
              --vad-filter \
              --language en
          '';
        };
      };
      "whisper-diarization" = {
        ttl = 0; # Keep resident for diarization requests.
        upstream = {
          # Redirect pyannote's home-directory lookup (~/.pyannote/database.yml)
          # away from /home (hidden by ProtectHome) to the writable whisperx cache.
          cmd = ''
            env HOME=${diarizationCache} \
            ${whisperDiarizePython}/bin/python3 ${../../modules/services/llama-swap/diarization-server.py} \
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
      };
      "kokoro-82m" = {
        ttl = 0; # Keep resident for low-latency TTS.
        upstream = {
          cmd = ''
            ${kokoroPython}/bin/python3 ${../../modules/services/llama-swap/kokoro-openai-server.py} \
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
    };
  };

  systemd.services.llama-swap.serviceConfig = {
    CacheDirectory = "llama-swap";
    ProcSubset = lib.mkForce "all";
    ProtectProc = lib.mkForce "default";
    DynamicUser = lib.mkForce false;
    User = "codyt";
    Group = "users";
    ReadWritePaths = lib.mkAfter [
      sharedFasterWhisperCache
      diarizationCache
      diarizationEnrollmentDir
    ];
  };
}
