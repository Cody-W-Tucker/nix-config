# Qwen 3.5 models context limits (Hugging Face spec):
# - All models: 262,144 tokens native (256K)
# - Recommended minimum: 128K for thinking capabilities
# - Batch size should equal context size for efficient GPU utilization
# - 35B Q8_0: ~38GB weights, 32K context fits safely in 92GB VRAM

{
  "qwen3.5-0.8b" = {
    file = "Qwen3.5-0.8B-UD-Q8_K_XL.gguf";
    gpuLayers = 999;
    contextSize = 65536;
    threads = 2;
    batchSize = 2048;
    ubatchSize = 2048;
    ttl = 300;
  };
  "qwen3.5-4b" = {
    file = "Qwen3.5-4B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 65536;
    threads = 4;
    batchSize = 4096;
    ubatchSize = 4096;
    ttl = 450;
  };
  "qwen3.5-9b" = {
    file = "Qwen3.5-9B-Q4_K_M.gguf";
    gpuLayers = 999;
    contextSize = 131072;
    threads = 8;
    batchSize = 8192;
    ubatchSize = 8192;
    ttl = 900;
  };
  "qwen3.5-9b-8" = {
    file = "Qwen3.5-9B-UD-Q8_K_XL.gguf";
    gpuLayers = 999;
    contextSize = 131072;
    threads = 8;
    batchSize = 8192;
    ubatchSize = 8192;
    ttl = 900;
  };
  "qwen3.5-35b" = {
    file = "Qwen3.5-35B-A3B-Q8_0.gguf";
    gpuLayers = 999;
    # 65536 context needed for ~44K+ token prompts
    # batchSize 8192 balances speed with 92GB VRAM
    contextSize = 65536;
    threads = 16;
    batchSize = 8192;
    ubatchSize = 8192;
    ttl = 1800;
  };
  "qwen3-embedding-8b" = {
    file = "Qwen3-Embedding-8B-Q4_K_M.gguf";
    gpuLayers = 999;
    contextSize = 40960;
    threads = 8;
    batchSize = 8192;
    ubatchSize = 8192;
    ttl = 300;
    extraArgs = [ "--embeddings" "--parallel" "6" ];
  };
  # Gemma 3 12B - Good balance of quality and speed for reasoning tasks
  # UD-Q4_K_XL quantization: ~7.0GB weights, fits well in 92GB VRAM with room for context
  "gemma-3-12b" = {
    file = "gemma-3-12b-it-UD-Q4_K_XL.gguf";
    gpuLayers = 999;
    contextSize = 131072;
    threads = 16;
    batchSize = 4096;
    ubatchSize = 4096;
    ttl = 1200;
  };
}
