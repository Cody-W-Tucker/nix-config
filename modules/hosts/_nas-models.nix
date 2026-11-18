{
  config,
  lib,
  pkgs,
  ...
}:

let
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

  # Qwen3.5-9B NVFP4 base GGUF for the text-only, non-reasoning qwen-3.5-9b endpoint.
  qwen35_9bBase = pkgs.fetchurl {
    url = "https://huggingface.co/FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF/resolve/3db49b5e08fb84a2ead8d6407f38f6638c79d08a/qwen3.5-9b-nvfp4.gguf";
    sha256 = "0db703913b6a1b057d423e9815095e9dc16499596a986446918314a48c4d9bad";
  };

  # s1-mini Q4_K_M GGUF (superwhisper) used as the speech-to-text transcript
  # normalizer (llama-dictate posts raw STT output to it).
  s1Mini = pkgs.fetchurl {
    url = "https://huggingface.co/superwhisper/s1-mini-GGUF/resolve/34add00a48a2e5d24e5a4ee5405a99620a3a240c/s1-mini-q4_k_m.gguf";
    sha256 = "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634";
  };

  # sherpa-onnx export of NVIDIA Parakeet TDT 0.6B v3 (int8) for the
  # parakeet-tdt-v3 STT endpoint. Pinned to an immutable commit; hashes are
  # the Hugging Face LFS sha256 values.
  parakeetTdtV3 =
    let
      rev = "ed5d745623472f97cfc2e6c2916ee248798fc5a8";
      fetch =
        name: sha256:
        pkgs.fetchurl {
          url = "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/${rev}/${name}";
          inherit sha256;
        };
    in
    pkgs.linkFarm "sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8" {
      "encoder.int8.onnx" =
        fetch "encoder.int8.onnx" "1afbe69c1ffdabee94755f42e4daf1d93549131a3da11356bda84fcef0f2c479";
      "decoder.int8.onnx" =
        fetch "decoder.int8.onnx" "0222a86147299d4dee90edf95b6d13827edb42ad8b7c9cf0b2582f030937c0b5";
      "joiner.int8.onnx" =
        fetch "joiner.int8.onnx" "cbd02f3696e9944970111fb439d9c3fd365a80374565f13f2b9c7007d253fc98";
      "tokens.txt" =
        fetch "tokens.txt" "d58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d";
    };

  # Laya Q8_0 GGUF (SystemOne speech endpoint). Pinned to an immutable
  # commit; content hash guards byte-identity (449397600 bytes).
  laya = pkgs.fetchurl {
    url = "https://huggingface.co/ggml-org/Laya-GGUF/resolve/22265007700297ba9e128297e82540cf28c5d7d4/Laya-Q8_0.gguf";
    sha256 = "c06528c5746d3bb8baa72a27938be95abbfd0b226f8471e8a9e365ed0bb066d2";
  };

in
{
  imports = [
    ../_legacy/services/llama-swap
  ];

  sops.secrets."huggingface-read" = {
    owner = config.codyos.site.user.name;
    group = "users";
    mode = "0400";
  };

  services.llama-swap = {
    enable = true;
    # Keep the router on nixos-unstable alongside the llama.cpp server, so
    # decision-endpoint support can move forward with the upstream packages.
    package = pkgs.unstable.llama-swap;
    # NAS intentionally tracks unstable llama-cpp 0.6.0 for SystemOne
    # (upstream PR #29818) while the host stays on stable pkgs. CUDA comes from
    # the host nixpkgs.config that pkgs.unstable inherits.
    serverPackage = pkgs.unstable.llama-cpp;
    parakeetModel = parakeetTdtV3;
    hfTokenPath = config.sops.secrets."huggingface-read".path;
    port = 8081;
    openFirewall = false;
    modelOwner = config.codyos.site.user.name;
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
      "parakeet-tdt-v3"
      "whisper-diarization"
      "kokoro-82m"
      "s1-mini"
      "laya"
    ];
    # laya stays on-demand (not preloaded): existing policy only keeps the
    # STT/s1-mini audio path warm; nothing here calls for laya at boot.
    preloadModels = [
      "parakeet-tdt-v3"
      "s1-mini"
    ];
    modelOverrides = {
      "qwen-3.5-4b" = {
        file = toString qwen35_4b;
        mmprojFile = toString qwen35_4bMmproj;
      };
      "qwen-3.5-9b" = {
        # Text-only (catalog sets no projector); the 4B endpoint serves vision.
        file = toString qwen35_9bBase;
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
      "laya" = {
        file = toString laya;
      };
    };
    # Embeddings can coexist with either audio or the 9B, without requiring
    # audio and the 9B to fit together. Unlisted models run alone, keeping
    # the 35B's GPU budget and unmeasured combinations conservative.
    settings.routing.router = {
      use = "matrix";
      settings.matrix = {
        vars = {
          embed = "qwen3-embedding-0.6b";
          stt = "parakeet-tdt-v3";
          kokoro = "kokoro-82m";
          normalize = "s1-mini";
          text = "qwen-3.5-9b";
        };
        sets = {
          audio = "embed & stt & kokoro & normalize";
          text = "embed & text";
        };
      };
    };
  };

  systemd.services.llama-swap.serviceConfig = {
    CacheDirectory = "llama-swap";
    ProcSubset = lib.mkForce "all";
    ProtectProc = lib.mkForce "default";
    DynamicUser = lib.mkForce false;
    User = config.codyos.site.user.name;
    Group = "users";
  };
}
