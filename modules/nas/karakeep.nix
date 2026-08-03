{
  mkNginxVhost,
  ...
}:

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
      OPENAI_BASE_URL = "http://nas:8081/v1";

      INFERENCE_TEXT_MODEL = "qwen3.5-9b-nvfp4";
      OCR_USE_LLM = "true";
      INFERENCE_IMAGE_MODEL = "qwen3.5-9b-nvfp4";
      INFERENCE_CONTEXT_LENGTH = "32768";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";

      EMBEDDING_ENABLE_AUTO_INDEXING = "true";
      EMBEDDING_TEXT_MODEL = "qwen3-embedding-0.6b";
      EMBEDDING_DIMENSIONS = "1024";
      EMBEDDING_CONTEXT_LENGTH = "8192";
      MAX_ASSET_SIZE_MB = "100";
    };
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "karakeep.homehub.tv";
    port = 3005;
    proxyWebsockets = true;
  };
}
