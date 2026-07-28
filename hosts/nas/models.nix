{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Import unstable nixpkgs with the same allowUnfreePredicate as the NAS config
  # so that CUDA-only unfree deps (e.g. cuda_cccl) are permitted without blanket allowUnfree.
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = config.nixpkgs.config.allowUnfreePredicate or (_: false);
  };

  # Keep the faster-whisper weights in the llama-swap service cache
  # so Open WebUI STT and whisp-away reuse one model download.
  sharedFasterWhisperCache = "/var/cache/llama-swap/faster-whisper";
  kokoroAssets = (pkgs.callPackage ../../packages/kokoro { }).assets;

  # CTranslate2 uses its own CMake CUDA_ARCH_LIST setting and does not inherit nixpkgs cudaCapabilities.
  # The bundled FindCUDA parser is too stale to accept CUDA_ARCH_LIST=12.0 for Blackwell,
  # so we strip any existing CUDA_ARCH_LIST flags and inject sm_120 directly via postPatch.
  ctranslate2CppBlackwell =
    let
      ctranslate2Cpp = pkgs.ctranslate2.override {
        withCUDA = true;
        withCuDNN = true;
      };
    in
    ctranslate2Cpp.overrideAttrs (old: {
      cmakeFlags = builtins.filter (
        f: !(builtins.isString f && builtins.match ".*CUDA_ARCH_LIST.*" f != null)
      ) (old.cmakeFlags or [ ]);
      postPatch = (old.postPatch or "") + ''
        # Bypass stale FindCUDA parser for Blackwell (sm_120): inject explicit
        # compute_120/sm_120 gencode after the existing ARCH_FLAGS expansion.
        for f in $(grep -rl 'list(APPEND CUDA_NVCC_FLAGS .*ARCH_FLAGS' .); do
          sed -i '/list(APPEND CUDA_NVCC_FLAGS .*ARCH_FLAGS/a\  list(APPEND CUDA_NVCC_FLAGS "-gencode" "arch=compute_120,code=sm_120")' "$f"
        done
      '';
    });

  whisperPython =
    let
      whisperScope = pkgs.python313.override {
        packageOverrides = final: prev: {
          ctranslate2 = prev.ctranslate2.override {
            ctranslate2-cpp = ctranslate2CppBlackwell;
          };
        };
      };
    in
    whisperScope.withPackages (
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
        ((pkgs.callPackage ../../packages/kokoro { pythonPkgs = ps; }).en-core-web-sm)
        fastapi
        kokoro
        numpy
        torchWithCuda
        uvicorn
      ]
    );

  # WhisperX diarization server: speech-to-text with speaker labels.
  # Uses WhisperX for transcription + alignment and pyannote for diarization.
  # Both require CUDA for acceptable latency.
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
  diarizationEmbeddingCache = "/var/lib/llama-swap/diarization/embedding-cache";
  diarizationCache = "/var/cache/llama-swap/whisperx";
in
{
  imports = [
    ../../modules/services/llama-swap
  ];

  assertions = [
    {
      # Guard: the diarization server hardcodes the embedding-cache path.
      # If it disappears from tmpfiles or ReadWritePaths, startup fails with
      # OSError: [Errno 30] Read-only file system.
      assertion =
        let
          rules = config.systemd.tmpfiles.rules;
          rwPaths = config.systemd.services.llama-swap.serviceConfig.ReadWritePaths or [ ];
          hasTmpfile = builtins.any (r: builtins.match ".*${diarizationEmbeddingCache}.*" r != null) rules;
          hasRwPath = builtins.elem diarizationEmbeddingCache rwPaths;
        in
        hasTmpfile && hasRwPath;
      message = "diarization embedding-cache (${diarizationEmbeddingCache}) must be in systemd.tmpfiles.rules and llama-swap ReadWritePaths";
    }
  ];

  sops.secrets."huggingface-read" = {
    owner = "codyt";
    group = "users";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    # CacheDirectory creates /var/cache/llama-swap as root:root; re-own for codyt so
    # HF_HOME and XDG_CACHE_HOME subdirectories are writable at runtime.
    "d /var/cache/llama-swap 0755 codyt users - -"
    "d /var/cache/llama-swap/huggingface 0755 codyt users - -"
    "d ${sharedFasterWhisperCache} 0755 codyt users - -"
    "d ${diarizationCache} 0755 codyt users - -"
    "d ${diarizationEnrollmentDir} 0750 codyt users - -"
    "d ${diarizationEmbeddingCache} 0750 codyt users - -"
  ];

  services.llama-swap = {
    enable = true;
    acceleration = "cuda";
    serverPackage = unstablePkgs.llama-cpp.override { cudaSupport = true; };
    port = 8081;
    modelOwner = "codyt";
    modelGroup = "users";
    serviceEnvironment = {
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
      # Shared catalog: embedding and OCR for Karakeep/Miniflux
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      # Audio stack: STT and TTS
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
          "kokoro-82m"
        ];
      };
    };
    modelOverrides = {
      "qwen3.5-0.8b" = {
        extraArgs = [
          "--reasoning"
          "off"
          "--parallel"
          "2"
        ];
      };
      "qwen3.5-4b" = {
        extraArgs = [
          "--reasoning"
          "off"
        ];
      };
      # Embeddings traffic is short-form; use a smaller KV/cache footprint and
      # avoid flash-attn to reduce startup instability in llama-server.
      "qwen3-embedding-0.6b" = {
        contextSize = 8192;
        batchSize = 1024;
        ubatchSize = 512;
        flashAttention = false;
      };
      # OCR prefers deterministic decoding. Allow a small amount of request
      # parallelism, but keep batching modest on the RTX 5060.
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
            PYTHONPATH=${../../modules/services/llama-swap} \
            ${whisperDiarizePython}/bin/python3 -m diarization.server \
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
      diarizationEmbeddingCache
    ];
  };
}
