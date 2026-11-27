# GGUF models served by llama-server. llama-swap.nix renders each entry into its
# command; settings an entry omits take the defaults there.
{ pkgs }:
let
  hf =
    repo: rev: name: sha256:
    pkgs.fetchurl {
      url = "https://huggingface.co/${repo}/resolve/${rev}/${name}";
      inherit sha256;
    };

  # Server-side sampling defaults from the Qwen3.5 / Qwen3.6 model cards
  # ("Best Practices"). Clients can still override them per request.
  qwenNonThinkingSampling = [
    "--temp"
    "0.7"
    "--top-p"
    "0.8"
    "--top-k"
    "20"
    "--min-p"
    "0"
    "--presence-penalty"
    "1.5"
  ];
  qwenThinkingSampling = [
    "--temp"
    "1.0"
    "--top-p"
    "0.95"
    "--top-k"
    "20"
    "--min-p"
    "0"
    "--presence-penalty"
    "1.5"
  ];
in
{
  "qwen-3.5-4b" = {
    file =
      hf "FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF" "fb9f8b9ec432e38872ec9d9707183642cf885ad6"
        "qwen3.5-4b-nvfp4.gguf"
        "317ef79785a9380ac72d23ab33af9376afd926b4c0781fae246f033daf91a05f";
    mmprojFile =
      hf "FreedomAISVR/Qwen3.5-4B-NVFP4-GGUF" "fb9f8b9ec432e38872ec9d9707183642cf885ad6"
        "mmproj-qwen3.5-4b-nvfp4-f16.gguf"
        "659b59dd44b73b1cd34af6cc424669484b06dc80f4340adf8ea84ad776eef813";
    ttl = 300;
    contextSize = 32768;
    gpuLayers = 999;
    # Slots share one unified KV pool (the full -c), so extra parallelism
    # costs little VRAM; concurrent requests split the 32K context.
    extraArgs = [
      "--fit"
      "off"
      "--parallel"
      "4"
      "--kv-unified"
      "--reasoning"
      "off"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
    ]
    ++ qwenNonThinkingSampling;
  };
  # Text-only; the 4B serves vision. 32K with a Q8 cache leaves room for embeddings.
  "qwen-3.5-9b" = {
    file =
      hf "FreedomAISVR/Qwen3.5-9B-NVFP4-GGUF" "3db49b5e08fb84a2ead8d6407f38f6638c79d08a"
        "qwen3.5-9b-nvfp4.gguf"
        "0db703913b6a1b057d423e9815095e9dc16499596a986446918314a48c4d9bad";
    ttl = 300;
    contextSize = 32768;
    gpuLayers = 999;
    extraArgs = [
      "--fit"
      "off"
      "--reasoning"
      "off"
      "--parallel"
      "4"
      "--kv-unified"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
    ]
    ++ qwenNonThinkingSampling;
  };
  # No `--n-gpu-layers` / `--n-cpu-moe`: `--fit` keeps as many experts on the GPU
  # as free VRAM allows and spills the rest to RAM. A fixed `--n-cpu-moe` OOMs
  # with the audio stack resident. Benchmarks for these flags are in Hindsight.
  #
  # `--spec-type draft-mtp` is required to load this GGUF at all: without it
  # llama.cpp rejects the MTP tensors ("wrong number of tensors").
  "qwen-3.6-35b-a3b" = {
    file =
      hf "michaelw9999/Qwen3.6-35B-A3B-NVFP4-MTP-GGUF" "df112dd576e55b1daa1331a7831b64ec9c03dbae"
        "Qwen3.6-35B-A3B-NVFP4-MTP-TURBO.gguf"
        "f3d2fdc74e3ef19925ccbf794b04d7f6f11fb12eba7722b7749219d0cc5c36ed";
    contextSize = 262144;
    ttl = 300;
    batchSize = 2048;
    ubatchSize = 1024;
    extraArgs = [
      "--fit-target"
      "512"
      "--parallel"
      "1"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q4_0"
      "--load-mode"
      "none"
      "--reasoning-budget"
      "2048"
      "--reasoning-budget-message"
      "Wait, I am overthinking. I should answer now."
      "--spec-type"
      "draft-mtp"
      "--spec-draft-n-max"
      "2"
    ]
    ++ qwenThinkingSampling;
  };
  "qwen3-embedding-0.6b" = {
    file =
      hf "Qwen/Qwen3-Embedding-0.6B-GGUF" "370f27d7550e0def9b39c1f16d3fbaa13aa67728"
        "Qwen3-Embedding-0.6B-Q8_0.gguf"
        "06507c7b42688469c4e7298b0a1e16deff06caf291cf0a5b278c308249c3e439";
    contextSize = 8192;
    batchSize = 512;
    ubatchSize = 512;
    flashAttention = false; # avoid flash-attn to reduce startup instability in llama-server.
    ttl = 300;
    gpuLayers = 999;
    # Many background clients (Hindsight, Karakeep, deja)
    # embed concurrently; eight slots share the unified 8K KV pool.
    extraArgs = [
      "--fit"
      "off"
      "--embeddings"
      "--pooling"
      "last"
      "--parallel"
      "8"
      "--kv-unified"
    ];
  };
  # Paperless-GPT sends no stop sequences or repetition controls, and llama-server
  # has no server-wide stop flag, so the repeat penalty below is the loop guard.
  # VISION_LLM_MAX_TOKENS=2048 on the Paperless-GPT side caps the output.
  "glm-ocr-f16" = {
    file =
      hf "ggml-org/GLM-OCR-GGUF" "65a42de1148dbed2297e922b5dbc7d9b70c36578" "GLM-OCR-f16.gguf"
        "b06675e983db9593db78603b06f097e48c0cf078b37731c0a09612f4a249cf6f";
    mmprojFile =
      hf "ggml-org/GLM-OCR-GGUF" "65a42de1148dbed2297e922b5dbc7d9b70c36578" "mmproj-GLM-OCR-Q8_0.gguf"
        "9c4b58e33e316ed142eb5dcb41abec3844d3e6e5dc361ffb782c3fa9d175141f";
    # Upstream's GLM-OCR example value; 8192 truncated real large-image requests.
    contextSize = 12000;
    batchSize = 1024;
    ubatchSize = 512;
    ttl = 5;
    # With flash attention the end-of-turn token is not recognized and output
    # runs to the context limit (llama.cpp discussion #19721).
    flashAttention = false;
    # `--fit off` (below) stops llama-server choosing placement, so pin
    # every layer to the GPU explicitly.
    gpuLayers = 999;
    extraArgs = [
      "--samplers"
      "top_k"
      "--top-k"
      "1"
      "--temp"
      "0"
      "--repeat-penalty"
      "1.1"
      "--repeat-last-n"
      "256"
      # Only K is quantized: llama.cpp refuses a quantized V cache without flash attention.
      "--cache-type-k"
      "q8_0"
      # Upstream GLM-OCR guidance requires --fit off to prevent memory auto-adjustment
      # from interfering with model-specific parameters.
      "--fit"
      "off"
    ];
  };
  # Dictation cleanup: rewrites raw transcripts, so it must return only the text.
  "s1-mini" = {
    file =
      hf "superwhisper/s1-mini-GGUF" "34add00a48a2e5d24e5a4ee5405a99620a3a240c" "s1-mini-q4_k_m.gguf"
        "3b41ebe2502cbd03e811d5d16b022f5ab551eda58d62597d152f89535003c634";
    contextSize = 8192;
    batchSize = 512;
    ubatchSize = 512;
    ttl = 30;
    gpuLayers = 999;
    extraArgs = [
      "--fit"
      "off"
      "--jinja"
      "--chat-template-kwargs"
      "{\"enable_thinking\":false}"
      "--temp"
      "0"
    ];
  };
}
