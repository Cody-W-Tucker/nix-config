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

  # Qwen3.6-35B-A3B NVFP4 MTP base GGUF for the qwen-3.6-35b-a3b text endpoint.
  # Pinned to an immutable release commit (df112dd5...) so the resolved source
  # is reproducible; the sha256 guards byte-identity. Public/not-gated upstream
  # artifact. ~19.7 GB; routed MoE experts are placed in CPU RAM at runtime via
  # --cpu-moe (see the shared catalog entry), so the Nix store holds the full
  # weights and llama-server streams expert tensors from here into system RAM.
  qwen36Base = pkgs.fetchurl {
    url = "https://huggingface.co/michaelw9999/Qwen3.6-35B-A3B-NVFP4-MTP-GGUF/resolve/df112dd576e55b1daa1331a7831b64ec9c03dbae/Qwen3.6-35B-A3B-NVFP4-MTP-TURBO.gguf";
    sha256 = "f3d2fdc74e3ef19925ccbf794b04d7f6f11fb12eba7722b7749219d0cc5c36ed";
  };

  # Qwen3.5-9B NVFP4 base GGUF for the qwen-3.5-9b non-task reasoning endpoint.
  # Pinned to an immutable release commit (3db49b5e...) so the resolved source
  # is reproducible; the sha256 guards byte-identity. Mirrors the historical
  # qwen35Base fetch that backed this endpoint before it was removed.
  qwen35_9bBase = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF/resolve/3db49b5e08fb84a2ead8d6407f38f6638c79d08a/qwen3.5-9b-nvfp4.gguf";
    sha256 = "0db703913b6a1b057d423e9815095e9dc16499596a986446918314a48c4d9bad";
  };

  # s1-mini Q4_K_M GGUF (superwhisper) used as the speech-to-text transcript
  # normalizer (llama-dictate posts raw Whisper output to it). Pinned to an
  # immutable release commit (34add00a...) so the resolved source is
  # reproducible; the sha256 guards byte-identity.
  s1Mini = pkgs.fetchurl {
    url = "https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/34add00a48a2e5d24e5a4ee5405a99620a3a240c/s1-mini-q4_k_m.gguf";
    sha256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634";
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
      "qwen-3.5-4b"
      # Qwen3.5-9B NVFP4: non-task reasoning endpoint, 64K context.
      "qwen-3.5-9b"
      # Qwen3.6-35B-A3B NVFP4: large text MoE, experts in CPU RAM via --cpu-moe.
      "qwen-3.6-35b-a3b"
      # Shared catalog: embedding and OCR for Karakeep/Miniflux
      "qwen3-embedding-0.6b"
      "glm-ocr-f16"
      # Audio stack: STT and TTS
      "whisper-medium"
      "whisper-diarization"
      "kokoro-82m"
      # s1-mini: speech-to-text transcript normalizer (chat-completions),
      # used by the desktop llama-dictate pipeline.
      "s1-mini"
    ];
    preloadModels = [
      "whisper-medium"
      "s1-mini"
    ];
    # qwen-3.5-4b overrides the shared catalog's relative filenames with
    # reproducible store paths (base + matching multimodal projector) fetched
    # above, so llama-server receives --model / --mmproj directly from the Nix
    # store instead of the runtime-cached model directory.
    modelOverrides."qwen-3.5-4b" = {
      file = toString qwen35_4b;
      mmprojFile = toString qwen35_4bMmproj;
      upstream.concurrencyLimit = 1;
    };
    # Qwen3.5-9B NVFP4 non-task reasoning endpoint: store-backed base GGUF
    # (no multimodal projector). Mirrors the historical non-task override.
    modelOverrides."qwen-3.5-9b" = {
      file = toString qwen35_9bBase;
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
    # s1-mini Q4_K_M: speech-to-text transcript normalizer. Store-backed GGUF
    # so llama-server receives --model directly from the Nix store.
    modelOverrides."s1-mini" = {
      file = toString s1Mini;
    };
    # Qwen3.6-35B-A3B NVFP4 is fetched reproducibly into the store; override the
    # catalog's relative filename with the absolute store path so llama-server
    # receives --model directly from the Nix store. MoE expert tensors are
    # offloaded to CPU RAM at runtime by the catalog's --cpu-moe flag.
    modelOverrides."qwen-3.6-35b-a3b" = {
      file = toString qwen36Base;
    };
    # llama-swap loading policy (see llama-swap groups semantics:
    # `swap` = members may run together when false; `exclusive` = loading a
    # member unloads EVERY other group; `persistent` = other groups cannot
    # unload it). A model may belong to exactly one group. All four groups are
    # mutually exclusive; every group is `exclusive=true` so any member load
    # evicts all other groups. Within-group co-residency is governed by `swap`:
    # only audio-stack and inference-stack set swap:false, so their members may
    # run together; OCR and 35B are single-member groups and therefore fully
    # standalone. All groups are persistent:false so any group can be evicted by
    # another's exclusive load.
    #
    # Permitted co-load sets:
    #   - audio-stack: all three audio models resident together (swap:false)
    #   - inference-stack: 4B LLM + 0.6B embedding resident together (swap:false)
    #   - ocr: standalone GLM-OCR (loading it evicts every other group)
    #   - 35b-exclusive: standalone MoE; loading it evicts every other group
    groups = {
      # audio-stack: whisper + diarization + kokoro stay resident as a unit.
      # swap:false lets all three run concurrently; exclusive:true means loading
      # any audio model evicts inference-stack, ocr and 35b-exclusive.
      audio-stack = {
        swap = false;
        exclusive = true;
        persistent = false;
        members = [
          "whisper-medium"
          "whisper-diarization"
          "kokoro-82m"
          # s1-mini normalizer co-resides with whisper-medium so the desktop
          # speech pipeline can run STT + normalization together.
          "s1-mini"
        ];
      };
      # inference-stack: the primary 4B LLM and the 0.6B embedding coexist for
      # Karakeep / Miniflux / Paperless-GPT. swap:false (both resident),
      # exclusive:true (loading either evicts audio-stack, ocr and 35b-exclusive).
      inference-stack = {
        swap = false;
        exclusive = true;
        persistent = false;
        members = [
          "qwen-3.5-4b"
          "qwen3-embedding-0.6b"
        ];
      };
      # 35b-exclusive: the large MoE owns the GPU. exclusive:true means loading
      # qwen-3.6-35b-a3b unloads EVERY other group (audio-stack, inference-stack,
      # ocr) — i.e. all other served models, including audio, 4B, embeddings and
      # OCR, are evicted. Single-member group, so `swap` is moot (kept true to
      # preserve the prior 35B swap behavior).
      "35b-exclusive" = {
        swap = true;
        exclusive = true;
        persistent = false;
        members = [
          "qwen-3.6-35b-a3b"
        ];
      };
      # ocr: standalone GLM-OCR. exclusive:true means loading OCR evicts every
      # other group (audio-stack, inference-stack, 35b-exclusive). Single-member
      # group, so `swap` is moot (kept false to preserve the prior OCR swap
      # behavior); non-persistent so any other group's exclusive load evicts it.
      ocr = {
        swap = false;
        exclusive = true;
        persistent = false;
        members = [
          "glm-ocr-f16"
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
