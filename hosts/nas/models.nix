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

  # Multimodal projector for qwen3.5-9b-nvfp4: extracted from the same
  # FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF release as the base GGUF.
  qwen35Mmproj = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF/resolve/main/mmproj-qwen3.5-9b-nvfp4-f16.gguf";
    sha256 = "97f420245a85ce129bb764e86a5e21e27d782fe6d6056c6839b9c5fdb8f38289";
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
    # Blackwell RTX 5060 requires sm_120a for FP4 tensor-core instructions.
    # Override per-package (not globally) to compile native sm_120a code.
    serverPackage = (unstablePkgs.llama-cpp.override { cudaSupport = true; }).overrideAttrs (old: {
      cmakeFlags =
        builtins.filter (f: !(builtins.isString f && builtins.match ".*CUDA_ARCHITECTURES.*" f != null)) (
          old.cmakeFlags or [ ]
        )
        ++ [ "-DCMAKE_CUDA_ARCHITECTURES=120a" ];
    });
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
      "qwen3.5-9b-nvfp4"
      # Shared catalog: embedding and OCR for Karakeep/Miniflux
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      # Audio stack: STT and TTS
      "whisper-medium"
      "whisper-diarization"
      "kokoro-82m"
    ];
    preloadModels = [ "whisper-medium" ];
    # Override the shared catalog's relative mmproj filename with the
    # reproducible store path fetched above so llama-server receives --mmproj.
    modelOverrides."qwen3.5-9b-nvfp4".mmprojFile = toString qwen35Mmproj;
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
