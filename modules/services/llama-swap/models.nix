{
  "qwen3.5-0.8b" = {
    file = "Qwen3.5-0.8B-UD-Q8_K_XL.gguf";
    gpuLayers = 1;
    contextSize = 8192;
    threads = 4;
    batchSize = 1024;
    ubatchSize = 512;
    ttl = 300;
  };
  "qwen3.5-4b" = {
    file = "Qwen3.5-4B-Q8_0.gguf";
    gpuLayers = 8;
    contextSize = 16384;
    threads = 8;
    batchSize = 1536;
    ubatchSize = 768;
    ttl = 450;
  };
  "qwen3.5-9b" = {
    file = "Qwen3.5-9B-Q4_K_M.gguf";
    gpuLayers = 16;
    contextSize = 32768;
    threads = 16;
    batchSize = 2048;
    ubatchSize = 1024;
    ttl = 600;
  };
  "qwen3.5-9b-8" = {
    file = "Qwen3.5-9B-UD-Q8_K_XL.gguf";
    gpuLayers = 999;
    contextSize = 32768;
    threads = 16;
    batchSize = 2048;
    ubatchSize = 1024;
    ttl = 600;
  };
  "qwen3.5-35b" = {
    file = "Qwen3.5-35B-A3B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 65536;
    threads = 32;
    batchSize = 2048;
    ubatchSize = 1024;
    ttl = 600;
  };
}
