{
  lib,
  pkgs,
  self,
  ...
}:

let
  # Keep the faster-whisper weights on the workspace volume so Open WebUI STT
  # and whisp-away reuse one model download.
  sharedFasterWhisperCache = "/mnt/work/cache/ai/faster-whisper";

  llamaAudioCompatPython =
    let
      # Kokoro (and future torch-based audio models) need a CUDA-enabled torch
      # for GPU inference. The base python313Packages.torch is CPU-only.
      torchWithCuda = pkgs.python313Packages.torch.override {
        cudaSupport = true;
      };
    in
    pkgs.python313.withPackages (
      ps: with ps; [
        accelerate
        datasets
        # Provide the spacy model that misaki's G2P (used by kokoro) requires.
        # Without it in the same env, misaki calls spacy.cli.download which fails
        # in the Nix python env (no pip/uv).
        (pkgs.callPackage ../../packages/en-core-web-sm { pythonPkgs = ps; })
        fastapi
        faster-whisper
        kokoro
        numpy
        python-multipart
        sentencepiece
        soundfile
        torchWithCuda
        transformers
        uvicorn
      ]
    );
in
{
  systemd.tmpfiles.rules = [
    "d ${sharedFasterWhisperCache} 0755 codyt users - -"
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
          "--parallel"
          "4"
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
            ${llamaAudioCompatPython}/bin/python3 ${../../modules/services/llama-swap/faster-whisper-openai-server.py} \
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
      "kokoro-82m" = {
        ttl = 0; # Keep resident for low-latency TTS.
        upstream = {
          cmd = ''
            ${llamaAudioCompatPython}/bin/python3 ${../../modules/services/llama-swap/kokoro-openai-server.py} \
              --host 127.0.0.1 \
              --port ''${PORT} \
              --model-id kokoro-82m \
              --lang-code a \
              --default-voice af_heart \
              --voices-dir ${self.packages.${pkgs.stdenv.hostPlatform.system}.kokoro-voices} \
              --model-path ${self.packages.${pkgs.stdenv.hostPlatform.system}.kokoro-model}/kokoro-v1_0.pth \
              --config-path ${self.packages.${pkgs.stdenv.hostPlatform.system}.kokoro-model}/config.json
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
    ReadWritePaths = lib.mkAfter [ sharedFasterWhisperCache ];
  };
}
