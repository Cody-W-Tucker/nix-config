{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Native nixpkgs llama.cpp CUDA build used as the llama-swap serverPackage.
  llamaCppCuda = pkgs.llama-cpp.override { cudaSupport = true; };

  # WORKAROUND: gate Laya/SystemOne on verified native llama.cpp threshold b11361.
  # Rationale: no upstream llama.cpp build now; native cached nixpkgs CUDA
  # build gains SystemOne at b11361 (first b-tag containing PR #29818 merge
  # a4cb4c61fd9d9c2066c7c1747821d3d65b8943bd, which registers /v1/systemone
  # in tools/server/server.cpp), with semantic 0.6.0 as the equivalent
  # semantic release. Numeric versions below b11361 (e.g. 9190) stay disabled.
  # Upstream: https://github.com/ggml-org/llama.cpp/pull/29818
  # REVIEW-BY: 2026-12-05
  # Once locked nixpkgs llama-cpp at/above the verified threshold is
  # established, remove this conditional and enable Laya unconditionally.
  nativeSystemOneSupported =
    let
      version = llamaCppCuda.version;
    in
    (builtins.match "^[0-9]+$" version != null && lib.versionAtLeast version "11361")
    || (lib.hasPrefix "0." version && lib.versionAtLeast version "0.6.0");

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

  # Qwen3.5-4B NVFP4
  qwen35_4b = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF/resolve/fb9f8b9ec432e38872ec9d9707183642cf885ad6/qwen3.5-4b-nvfp4.gguf";
    sha256 = "317ef79785a9380ac72d23ab33af9376afd926b4c0781fae246f033daf91a05f";
  };
  # Multimodal projector for qwen-3.5-4b
  qwen35_4bMmproj = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF/resolve/fb9f8b9ec432e38872ec9d9707183642cf885ad6/mmproj-qwen3.5-4b-nvfp4-f16.gguf";
    sha256 = "659b59dd44b73b1cd34af6cc424669484b06dc80f4340adf8ea84ad776eef813";
  };

  # Qwen3.6-35B-A3B NVFP4 MTP base GGUF for the qwen-3.6-35b-a3b text endpoint.
  qwen36Base = pkgs.fetchurl {
    url = "https://huggingface.co/michaelw9999/Qwen3.6-35B-A3B-NVFP4-MTP-GGUF/resolve/df112dd576e55b1daa1331a7831b64ec9c03dbae/Qwen3.6-35B-A3B-NVFP4-MTP-TURBO.gguf";
    sha256 = "f3d2fdc74e3ef19925ccbf794b04d7f6f11fb12eba7722b7749219d0cc5c36ed";
  };

  # Qwen3.5-9B NVFP4 multimodal pair for the qwen-3.5-9b reasoning endpoint.
  qwen35_9bBase = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF/resolve/3db49b5e08fb84a2ead8d6407f38f6638c79d08a/qwen3.5-9b-nvfp4.gguf";
    sha256 = "0db703913b6a1b057d423e9815095e9dc16499596a986446918314a48c4d9bad";
  };
  qwen35_9bMmproj = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF/resolve/3db49b5e08fb84a2ead8d6407f38f6638c79d08a/mmproj-qwen3.5-9b-nvfp4-f16.gguf";
    sha256 = "97f420245a85ce129bb764e86a5e21e27d782fe6d6056c6839b9c5fdb8f38289";
  };

  # s1-mini Q4_K_M GGUF (superwhisper) used as the speech-to-text transcript
  # normalizer (llama-dictate posts raw Whisper output to it).
  s1Mini = pkgs.fetchurl {
    url = "https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/34add00a48a2e5d24e5a4ee5405a99620a3a240c/s1-mini-q4_k_m.gguf";
    sha256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634";
  };

  # Laya Q8_0 GGUF (SystemOne speech endpoint). Pinned to an immutable
  # commit; content hash guards byte-identity (449397600 bytes).
  # Fetched only when the native serverPackage supports SystemOne; below
  # b11361 (e.g. 9190) this stays null so no fetch artifact activates.
  laya =
    if nativeSystemOneSupported then
      pkgs.fetchurl {
        url = "https://huggingface.co/ggml-org/Laya-GGUF/resolve/22265007700297ba9e128297e82540cf28c5d7d4/Laya-Q8_0.gguf";
        sha256 = "c06528c5746d3bb8baa72a27938be95abbfd0b226f8471e8a9e365ed0bb066d2";
      }
    else
      null;

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
    serverPackage = llamaCppCuda;
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
      "qwen-3.5-4b"
      "qwen-3.5-9b"
      "qwen-3.6-35b-a3b"
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      "whisper-medium"
      "whisper-diarization"
      "kokoro-82m"
      "s1-mini"
    ]
    ++ lib.optionals nativeSystemOneSupported [ "laya" ];
    # laya stays on-demand (not preloaded): existing policy only keeps the
    # whisper/s1-mini audio path warm; nothing here calls for laya at boot.
    preloadModels = [
      "whisper-medium"
      "s1-mini"
    ];
    modelOverrides = {
      "qwen-3.5-4b" = {
        file = toString qwen35_4b;
        mmprojFile = toString qwen35_4bMmproj;
        upstream.concurrencyLimit = 1;
      };
      "qwen-3.5-9b" = {
        file = toString qwen35_9bBase;
        mmprojFile = toString qwen35_9bMmproj;
      };
      "qwen3-embedding-0.6b" = {
        file = toString qwen3Embedding;
      };
      "glm-ocr-f16" = {
        file = toString glmOcrF16;
        mmprojFile = toString glmOcrMmproj;
      };
      "s1-mini" = {
        file = toString s1Mini;
      };
      "qwen-3.6-35b-a3b" = {
        file = toString qwen36Base;
      };
    }
    // lib.optionalAttrs nativeSystemOneSupported {
      "laya" = {
        file = toString laya;
      };
    };
    # llama-swap loading policy (see llama-swap groups semantics:
    # `swap` = members may run together when false; `exclusive` = loading a
    # member unloads EVERY other group; `persistent` = other groups cannot
    # unload it). A model may belong to exactly one group. All groups are
    # mutually exclusive; every group is `exclusive=true` so any member load
    # evicts all other groups. Within-group co-residency is governed by `swap`:
    # swap:false, so their members may run together;
    groups = {
      audio-stack = {
        swap = false;
        exclusive = true;
        persistent = false;
        members = [
          "whisper-medium"
          "kokoro-82m"
          "s1-mini"
        ];
      };
      inference-stack = {
        swap = false;
        exclusive = true;
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
