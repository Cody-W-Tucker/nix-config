{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  unstablePkgs = import inputs.nixpkgs-unstable {
    system = "x86_64-linux";
    config = config.nixpkgs.config;
  };

  # llama.cpp selects Blackwell/NVFP4 architectures upstream; no local
  # CMAKE_CUDA_ARCHITECTURES override is needed here.
  unstableLlamaCpp = unstablePkgs.llama-cpp.override {
    cudaSupport = true;
  };

  # Multimodal projector for qwen-3.5-9b-task: extracted from the same
  # FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF release as the base GGUF.
  #
  # RESIDUAL RISK (intentional): pinned by content hash only, NOT by an
  # immutable commit reference. The URL still points at the mutable
  # `resolve/main/` HEAD, so a future upstream force-push could move the
  # artifact the hash is verified against. The sha256 still guarantees
  # byte-identity at fetch time. Recorded so the mutable `main` reference is
  # not mistaken for a verified immutable source. Convert to a
  # `resolve/<commit>/` URL once the artifact is confirmed present at a commit.
  qwen35Mmproj = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF/resolve/main/mmproj-qwen3.5-9b-nvfp4-f16.gguf";
    sha256 = "97f420245a85ce129bb764e86a5e21e27d782fe6d6056c6839b9c5fdb8f38289";
  };

  # Qwen3 embedding GGUF (karakeep/miniflux shared catalog). Pinned to an
  # immutable release commit; content hash guards byte-identity.
  qwen3Embedding = pkgs.fetchurl {
    url = "https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/370f27d7550e0def9b39c1f16d3fbaa13aa67728/Qwen3-Embedding-0.6B-Q8_0.gguf";
    sha256 = "06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439";
  };

  # GLM OCR base + multimodal projector (karakeep/miniflux shared catalog).
  # Both pinned to the same immutable release commit.
  glmOcrF16 = pkgs.fetchurl {
    url = "https://huggingface.co/ggml-org/GLM-OCR-GGUF/resolve/65a42de1148dbed2297e922b5dbc7d9b70c36578/GLM-OCR-f16.gguf";
    sha256 = "b06675e983db9593db78603b06f097e48c0cf078b37731c0a09612f4a249cf6f";
  };
  glmOcrMmproj = pkgs.fetchurl {
    url = "https://huggingface.co/ggml-org/GLM-OCR-GGUF/resolve/65a42de1148dbed2297e922b5dbc7d9b70c36578/mmproj-GLM-OCR-Q8_0.gguf";
    sha256 = "9c4b58e33e316ed142eb5dcb41abec3844d3e6e5dc361ffb782c3fa9d175141f";
  };

  # Base NVFP4 GGUF for both qwen-3.5-9b endpoints. Pinned to an immutable
  # release commit (3db49b5e...) so the resolved source is reproducible; the
  # sha256 still guards byte-identity. The artifact is byte-identical to the
  # runtime-cached file it replaces at /srv/llama-swap/models/qwen3.5-9b-nvfp4.gguf.
  qwen35Base = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF/resolve/3db49b5e08fb84a2ead8d6407f38f6638c79d08a/qwen3.5-9b-nvfp4.gguf";
    sha256 = "0db703913b6a1b057d423e9815095e9dc16499596a986446918314a48c4d9bad";
  };

  # Qwen3.5-0.8B base GGUF for the qwen3.5-0.8b endpoint. Pinned to an immutable
  # release commit (6ab461498e...) so the resolved source is reproducible; the
  # sha256 guards byte-identity. Public/not-gated upstream artifact.
  qwen35_08b = pkgs.fetchurl {
    url = "https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/6ab461498e2023f6e3c1baea90a8f0fe38ab64d0/Qwen3.5-0.8B-Q8_0.gguf";
    sha256 = "0ad885ffd4bb022fc4f0d33a3308fa108ef8613159d3b3a67e23abca056b7a6c";
  };

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
in
{
  imports = [
    ../../modules/services/llama-swap
  ];

  sops.secrets."huggingface-read" = {
    owner = "codyt";
    group = "users";
    mode = "0400";
  };

  services.llama-swap = {
    enable = true;
    acceleration = "cuda";
    serverPackage = unstableLlamaCpp;
    ctranslate2Cpp = ctranslate2CppBlackwell;
    hfTokenPath = config.sops.secrets."huggingface-read".path;
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
      "qwen-3.5-9b-task"
      "qwen-3.5-9b"
      # Shared catalog: embedding and OCR for Karakeep/Miniflux
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      # Audio stack: STT and TTS
      "whisper-medium"
      "whisper-diarization"
      "kokoro-82m"
    ];
    preloadModels = [ "whisper-medium" ];
    # Override the shared catalog's relative filenames with reproducible store
    # paths fetched above so llama-server receives --model / --mmproj directly
    # from the Nix store instead of the runtime-cached model directory.
    modelOverrides."qwen-3.5-9b-task" = {
      file = toString qwen35Base;
      mmprojFile = toString qwen35Mmproj;
      upstream.concurrencyLimit = 1;
    };
    # Reasoning endpoint shares the same base weights as the task model.
    modelOverrides."qwen-3.5-9b" = {
      file = toString qwen35Base;
    };
    # Embedding + OCR are fetched reproducibly into the store; override the
    # catalog's relative filenames with absolute store paths so llama-server
    # receives --model/--mmproj directly from the Nix store.
    modelOverrides."qwen3-embedding-0.6b" = {
      file = toString qwen3Embedding;
    };
    modelOverrides."glm-ocr-f16" = {
      file = toString glmOcrF16;
      mmprojFile = toString glmOcrMmproj;
    };
    # qwen3.5-0.8b is now store-backed through an immutable Unsloth artifact
    # URL with a verified hash (see qwen35_08b above). Replaces the prior
    # runtime-managed exception now that upstream provenance is confirmed.
    modelOverrides."qwen3.5-0.8b" = {
      file = toString qwen35_08b;
    };
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
  };

  systemd.services.llama-swap.serviceConfig = {
    CacheDirectory = "llama-swap";
    ProcSubset = lib.mkForce "all";
    ProtectProc = lib.mkForce "default";
    DynamicUser = lib.mkForce false;
    User = "codyt";
    Group = "users";
  };
}
