# Multimodal models must also set `mmprojFile` to the matching projector GGUF
# or llama-server will reject image input even if the base model supports vision.
#
# Upstream repos often publish generic projector names such as `mmproj-F16.gguf`.
# Rename them when downloading into `/srv/llama-swap/models` so different model
# families do not overwrite each other.
#
# This file contains shared default model configurations. Host-specific overrides
# (e.g. wrapper commands that reference host-specific Python environments) are
# merged in default.nix.

{
  "qwen3.5-0.8b" = {
    file = "Qwen3.5-0.8B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 16384;
    threads = 6;
    batchSize = 1024;
    ubatchSize = 512;
    ttl = 60;
    extraArgs = [
      "--reasoning"
      "off"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
    ];
  };
  # Qwen3.5-9B in NVIDIA FP4 (NVFP4) — multimodal, non-reasoning task endpoint.
  # ~5.5 GB weights, fits alongside Q8 KV cache at 32K context on a 8 GB RTX 5060: 6GB total.
  "qwen-3.5-9b-task" = {
    file = "qwen3.5-9b-nvfp4.gguf";
    mmprojFile = "mmproj-qwen3.5-9b-nvfp4-f16.gguf";
    gpuLayers = 999;
    contextSize = 32768;
    threads = 6;
    batchSize = 2048;
    ubatchSize = 1024;
    ttl = 5;
    extraArgs = [
      "--parallel"
      "1"
      "--reasoning"
      "off"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
    ];
  };
  # Qwen3.5-9B reasoning-only endpoint. Same base weights as the task model,
  # no multimodal projector, 64K context for long-form reasoning.
  "qwen-3.5-9b" = {
    file = "qwen3.5-9b-nvfp4.gguf";
    gpuLayers = 999;
    contextSize = 65536;
    threads = 6;
    batchSize = 2048;
    ubatchSize = 1024;
    ttl = 600;
    extraArgs = [
      "--reasoning"
      "off"
      "--parallel"
      "1"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
    ];
  };
  "qwen3-embedding-0.6b" = {
    file = "Qwen3-Embedding-0.6B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 8192;
    threads = 6;
    batchSize = 512;
    ubatchSize = 512;
    flashAttention = false; # avoid flash-attn to reduce startup instability in llama-server.
    ttl = 5;
    extraArgs = [
      "--embeddings"
      "--pooling"
      "last"
    ];
  };
  # OCR prefers deterministic decoding. Allow a small amount of request
  # parallelism, but keep batching modest on the RTX 5060.
  #
  # Repetition-loop protection: Paperless-GPT sends OCR requests to this model
  # via the OpenAI-compatible API but does NOT send stop sequences or any
  # repetition controls (verified in upstream ocr/llm_provider.go — the
  # langchaingo OpenAI client is created with only WithModel/WithToken).
  # llama-server also has no CLI flag for server-wide default stop sequences,
  # so stop cannot be configured at this layer.
  #
  # The strongest config-only defence is a server-side repeat penalty:
  #   --repeat-penalty 1.1   conservative; discourages pure loops without
  #                           harming legitimately repeated tokens in OCR
  #                           output (table lines, dashed borders, etc.)
  #   --repeat-last-n  256   window over which repeated tokens are penalised;
  #                           large enough to catch medium-range loops while
  #                           leaving short repeated punctuation alone.
  # The hard output cap (VISION_LLM_MAX_TOKENS=2048 on the Paperless-GPT
  # side) remains the last-resort bound on runaway generation.
  "glm-ocr-f16" = {
    file = "GLM-OCR-f16.gguf";
    mmprojFile = "mmproj-GLM-OCR-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 12000;
    # Logs showed a real OCR request used 7044 prompt + 1148 completion = 8192
    # tokens and hit `truncated=1`; normal short OCR stops well below the boundary.
    # Upstream llama.cpp GLM-OCR example uses `-c 12000`. 12000 leaves headroom
    # for large-image prompts without masking runaway generation (the repeat
    # penalty and VISION_LLM_MAX_TOKENS=2048 still bound output).
    threads = 6;
    batchSize = 1024;
    ubatchSize = 512;
    ttl = 5;
    # Upstream GLM-OCR guidance (llama.cpp discussion #19721) requires flash
    # attention disabled. Without this, the model's special token handling breaks
    # (evidenced by "special_eot_id is not in special_eog_ids" warning), causing
    # the model to not recognize its natural stopping point and generate until
    # context limit (truncated=1 at 8191 tokens).
    flashAttention = false;
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
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
      # Upstream GLM-OCR guidance requires --fit off to prevent memory auto-adjustment
      # from interfering with model-specific parameters.
      "--fit"
      "off"
    ];
  };
  # Wrapper-backed audio models: file is null because the host replaces the
  # generated llama-server command with an OpenAI-compatible helper process.
  # Wrapper commands are built in default.nix using proxy.nix.
  "whisper-medium" = {
    file = null;
    ttl = 0; # Keep STT warm until another group explicitly evicts it.
  };
  "whisper-diarization" = {
    file = null;
    ttl = 300; # Keep resident for diarization requests.
  };
  "kokoro-82m" = {
    file = null;
    ttl = 0; # Keep TTS warm until another group explicitly evicts it.
  };
}
