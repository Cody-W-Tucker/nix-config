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
  # Qwen3.5-9B in NVIDIA FP4 (NVFP4) — ~5.5 GB weights, fits alongside Q8 KV cache at 32K context on a 8 GB RTX 5060: 6GB total.
  "qwen3.5-9b-nvfp4" = {
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
      "2"
      "--reasoning"
      "off"
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
  "glm-ocr-f16" = {
    file = "GLM-OCR-f16.gguf";
    mmprojFile = "mmproj-GLM-OCR-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 8192;
    threads = 6;
    batchSize = 1024;
    ubatchSize = 512;
    ttl = 5;
    extraArgs = [
      "--samplers"
      "top_k"
      "--top-k"
      "1"
      "--temp"
      "0"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
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
