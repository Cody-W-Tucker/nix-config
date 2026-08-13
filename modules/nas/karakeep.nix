{
  mkNginxVhost,
  ...
}:

{
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      PORT = "3005";
      DB_WAL_MODE = "true"; # This should improve the performance of the database.
      DISABLE_SIGNUPS = "true";
      DISABLE_NEW_RELEASE_CHECK = "true";
      OPENAI_API_KEY = "blank";
      OPENAI_BASE_URL = "http://nas:8081/v1";

      INFERENCE_TEXT_MODEL = "qwen-3.5-9b";
      OCR_USE_LLM = "true";
      INFERENCE_IMAGE_MODEL = "qwen-3.5-9b-task";
      INFERENCE_CONTEXT_LENGTH = "8192";
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
