{
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      PORT = "3005";
      LOG_LEVEL = "warning"; # Switch to warning after live.
      DB_WAL_MODE = "true"; # Enables WAL mode for the sqlite database. This should improve the performance of the database.
      # DISABLE_SIGNUPS = "true";
      DISABLE_NEW_RELEASE_CHECK = "true";
      OPENAI_API_KEY = "opencode";
      OPENAI_BASE_URL = "http://beast:8081/v1";
      INFERENCE_TEXT_MODEL = "qwen3.5-4b";
      # beast runs qwen3.5-4b at an 8K llama.cpp context. Leave headroom for
      # Karakeep's system prompt and structured-output schema so requests stay
      # under the model limit instead of failing at ~8.3K prompt tokens.
      INFERENCE_CONTEXT_LENGTH = "6144";
      INFERENCE_MAX_OUTPUT_TOKENS = "1024";
      INFERENCE_OUTPUT_SCHEMA = "structured";
      INFERENCE_IMAGE_MODEL = "glm-ocr-q8";
      EMBEDDING_TEXT_MODEL = "qwen3-embedding-0.6b";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
      INFERENCE_FETCH_TIMEOUT_SEC = "300"; # Default 5 mins
      INFERENCE_JOB_TIMEOUT_SEC = "300"; # Default 30s, increased for slow local model
      OCR_USE_LLM = "true"; # Use beast's multimodal OCR model for image text extraction.
      MAX_ASSET_SIZE_MB = "100";
    };
  };

  services.nginx.virtualHosts."karakeep.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:3005";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
    kTLS = true;
  };
}
