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

  # Qwen3.5-0.8B base GGUF for the qwen3.5-0.8b endpoint. Pinned to an immutable
  # release commit (6ab461498e...) so the resolved source is reproducible; the
  # sha256 guards byte-identity. Public/not-gated upstream artifact.
  qwen35_08b = pkgs.fetchurl {
    url = "https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/6ab461498e2023f6e3c1baea90a8f0fe38ab64d0/Qwen3.5-0.8B-Q8_0.gguf";
    sha256 = "0ad885ffd4bb022fc4f0d33a3308fa108ef8613159d3b3a67e23abca056b7a6c";
  };

  # Qwen3.5-4B NVFP4 base GGUF for the qwen-3.5-4b endpoint. Pinned to an
  # immutable release commit (fb9f8b9e...) so the resolved source is
  # reproducible; the sha256 guards byte-identity. Multimodal: the matching
  # projector below is extracted from the same FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF
  # release. ~2.4 GB weights; fits alongside the embedding + OCR/whisper on the
  # 8 GB RTX 5060 (see models.nix qwen-3.5-4b footprint comment).
  qwen35_4b = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF/resolve/fb9f8b9ec432e38872ec9d9707183642cf885ad6/qwen3.5-4b-nvfp4.gguf";
    sha256 = "317ef79785a9380ac72d23ab33af9376afd926b4c0781fae246f033daf91a05f";
  };
  # Multimodal projector for qwen-3.5-4b: extracted from the same
  # FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF release as the base GGUF. Pinned to the
  # same immutable release commit; the sha256 guards byte-identity.
  qwen35_4bMmproj = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF/resolve/fb9f8b9ec432e38872ec9d9707183642cf885ad6/mmproj-qwen3.5-4b-nvfp4-f16.gguf";
    sha256 = "659b59dd44b73b1cd34af6cc424669484b06dc80f4340adf8ea84ad776eef813";
  };

  # Qwen3.6-35B-A3B NVFP4 base GGUF for the qwen-3.6-35b-a3b text endpoint.
  # Pinned to an immutable release commit (95ba642c...) so the resolved source
  # is reproducible; the sha256 guards byte-identity. Public/not-gated upstream
  # artifact. ~19.7 GB; routed MoE experts are placed in CPU RAM at runtime via
  # --cpu-moe (see the shared catalog entry), so the Nix store holds the full
  # weights and llama-server streams expert tensors from here into system RAM.
  qwen36Base = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.6-35B-A3B-NVFP4-GGUF/resolve/95ba642c5138d24c01a2a52ca3372ba55762fd5d/qwen3.6-35b-a3b-nvfp4.gguf";
    sha256 = "6f2187c933978f7a45bc30cd6052fe2279d22ac5f6a98dd294166407079c889f";
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
      "qwen-3.5-4b"
      # Qwen3.6-35B-A3B NVFP4: large text MoE, experts in CPU RAM via --cpu-moe.
      "qwen-3.6-35b-a3b"
      # Shared catalog: embedding and OCR for Karakeep/Miniflux
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      # Audio stack: STT and TTS
      "whisper-medium"
      "whisper-diarization"
      "kokoro-82m"
    ];
    preloadModels = [ "whisper-medium" ];
    # qwen-3.5-4b overrides the shared catalog's relative filenames with
    # reproducible store paths (base + matching multimodal projector) fetched
    # above, so llama-server receives --model / --mmproj directly from the Nix
    # store instead of the runtime-cached model directory.
    modelOverrides."qwen-3.5-4b" = {
      file = toString qwen35_4b;
      mmprojFile = toString qwen35_4bMmproj;
      upstream.concurrencyLimit = 1;
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
    # Qwen3.6-35B-A3B NVFP4 is fetched reproducibly into the store; override the
    # catalog's relative filename with the absolute store path so llama-server
    # receives --model directly from the Nix store. MoE expert tensors are
    # offloaded to CPU RAM at runtime by the catalog's --cpu-moe flag.
    modelOverrides."qwen-3.6-35b-a3b" = {
      file = toString qwen36Base;
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
      # inference-stack: keeps the primary 4B LLM and the 0.6B embedding
      # loadable at the same time. Non-exclusive + non-swapping means neither
      # evicts the other; both can be resident concurrently on the 8 GB RTX 5060
      # (see models.nix qwen-3.5-4b footprint comment). This is what permits the
      # 4B and the embedding to coexist for Karakeep / Miniflux / Pythia /
      # Paperless-GPT.
      inference-stack = {
        swap = false;
        exclusive = false;
        persistent = false;
        members = [
          "qwen-3.5-4b"
          "qwen3-embedding-0.6b"
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
