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
      INFERENCE_CONTEXT_LENGTH = "32000";
      INFERENCE_MAX_OUTPUT_TOKENS = "1024";
      INFERENCE_OUTPUT_SCHEMA = "structured";
      EMBEDDING_TEXT_MODEL = "qwen3-embedding-0.6b";
      INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
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
