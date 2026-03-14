# Batch size guidelines for aiserver (92GB VRAM):
# - batchSize: Max context size for KV cache. 35B Q8_0 uses ~35GB weights + KV cache.
# - ubatchSize: Micro-batch parallelism. Keep equal to batchSize for best throughput.
# - Leave 10-20% VRAM headroom for runtime overhead (GGML, prompt buffering, etc.)
# - 35B Q8_0: 4096-8192 fits safely, 16384+ may OOM with long contexts
{
  "qwen3.5-0.8b" = {
    file = "Qwen3.5-0.8B-UD-Q8_K_XL.gguf";
    gpuLayers = 999;
    contextSize = 8192;
    threads = 2;
    batchSize = 1024;
    ubatchSize = 512;
    ttl = 300;
  };
  "qwen3.5-4b" = {
    file = "Qwen3.5-4B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 16384;
    threads = 4;
    batchSize = 1536;
    ubatchSize = 768;
    ttl = 450;
  };
  "qwen3.5-9b" = {
    file = "Qwen3.5-9B-Q4_K_M.gguf";
    gpuLayers = 999;
    contextSize = 32768;
    threads = 8;
    batchSize = 2048;
    ubatchSize = 512;
    ttl = 900;
  };
  "qwen3.5-9b-8" = {
    file = "Qwen3.5-9B-UD-Q8_K_XL.gguf";
    gpuLayers = 999;
    contextSize = 32768;
    threads = 8;
    batchSize = 2048;
    ubatchSize = 512;
    ttl = 900;
  };
  "qwen3.5-35b" = {
    file = "Qwen3.5-35B-A3B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 65536;
    threads = 16;
    batchSize = 4096;
    ubatchSize = 4096;
    ttl = 1800;
  };
}
