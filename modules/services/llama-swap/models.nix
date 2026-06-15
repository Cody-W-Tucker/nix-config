# Qwen 3.5 models context limits (Hugging Face spec):
# - All models: 262,144 tokens native (256K)
# - Recommended minimum: 128K for thinking capabilities
# - Batch size should equal context size for efficient GPU utilization
# - 35B Q8_0: ~38GB weights, 32K context fits safely in 92GB VRAM
#
# Multimodal models must also set `mmprojFile` to the matching projector GGUF
# or llama-server will reject image input even if the base model supports vision.
#
# Upstream repos often publish generic projector names such as `mmproj-F16.gguf`.
# Rename them when downloading into `/srv/llama-swap/models` so different model
# families do not overwrite each other.

{
  "qwen3.5-0.8b" = {
    file = "Qwen3.5-0.8B-UD-Q8_K_XL.gguf";
    gpuLayers = 999;
    contextSize = 16384;
    threads = 2;
    batchSize = 2048;
    ubatchSize = 2048;
    ttl = 300;
  };
  "qwen3.5-4b" = {
    file = "Qwen3.5-4B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 8192;
    threads = 4;
    batchSize = 512;
    ubatchSize = 512;
    ttl = 450;
  };
  "qwen3-embedding-0.6b" = {
    file = "Qwen3-Embedding-0.6B-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 32768;
    threads = 4;
    batchSize = 4096;
    ubatchSize = 2048;
    ttl = 300;
    extraArgs = [
      "--embeddings"
      "--pooling"
      "last"
    ];
  };
  # Wrapper-backed audio models can omit `file` because beast replaces the
  # generated llama-server command with an OpenAI-compatible helper process.
  "whisper-medium" = {
    ttl = 300;
  };
  "kokoro-82m" = {
    ttl = 0; # Keep TTS warm (resident model load) until another group evicts it.
  };
  # GLM-OCR-f16 - multimodal OCR model for document/image text extraction.
  "glm-ocr-f16" = {
    file = "GLM-OCR-f16.gguf";
    mmprojFile = "mmproj-GLM-OCR-Q8_0.gguf";
    gpuLayers = 999;
    contextSize = 8192;
    threads = 8;
    batchSize = 2048;
    ubatchSize = 1024;
    ttl = 600;
  };
}
