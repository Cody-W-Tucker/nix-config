{
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      PORT = "3005";
      LOG_LEVEL = "debug"; # Switch to warning after live.
      DB_WAL_MODE = "true"; # Enables WAL mode for the sqlite database. This should improve the performance of the database.
      # DISABLE_SIGNUPS = "true";
      DISABLE_NEW_RELEASE_CHECK = "true";
      OPENAI_API_KEY = "ollama";
      OLLAMA_BASE_URL = "http://aiserver:8080/v1";
      INFERENCE_TEXT_MODEL = "qwen3.5-35b";
      INFERENCE_CONTEXT_LENGTH = "65536";
      INFERENCE_MAX_OUTPUT_TOKENS = "2048";
      INFERENCE_OUTPUT_SCHEMA = "structured";
      INFERENCE_IMAGE_MODEL = "qwen3.5-35b";
      EMBEDDING_TEXT_MODEL = "qwen3-embedding-8b";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
      INFERENCE_FETCH_TIMEOUT_SEC = "300"; # Default 5 mins
      OCR_USE_LLM = "true"; # uses the configured inference model for OCR instead of Tesseract.
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
