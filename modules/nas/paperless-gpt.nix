{
  mkNginxVhost,
  config,
  ...
}:

{
  # Env file supplying secrets the upstream container requires.
  # Expected format (plain KEY=VALUE lines):
  #   PAPERLESS_API_TOKEN=<token>   # authenticates to the Paperless API
  sops.secrets."paperless-ai-env" = { };

  # Create persistent directories for prompts and config.
  # The upstream paperless-gpt image runs as UID/GID 10001 and must be
  # able to write into /app/prompts and /app/config, so the host mounts
  # are owned by that UID with owner-write permissions.
  systemd.tmpfiles.rules = [
    "d /var/lib/paperless-gpt 0755 root root -"
    "d /var/lib/paperless-gpt/prompts 0755 10001 10001 -"
    "d /var/lib/paperless-gpt/config 0755 10001 10001 -"
  ];

  virtualisation.oci-containers.containers.paperless-gpt = {
    autoStart = true;
    image = "icereed/paperless-gpt:latest";
    environment = {
      # With host networking, reach the host's Paperless API directly via localhost.
      PAPERLESS_BASE_URL = "http://127.0.0.1:28981";
      # Listen on port 28983 (same as previous paperless-ai for continuity)
      LISTEN_INTERFACE = ":28983";
      # Use OpenAI-compatible provider
      LLM_PROVIDER = "openai";
      OPENAI_BASE_URL = "http://127.0.0.1:8081/v1";
      OPENAI_API_KEY = "localonly";
      LLM_MODEL = "qwen-3.5-9b";
      # LLM-based OCR using the dedicated GLM-OCR vision model.
      OCR_PROVIDER = "llm";
      VISION_LLM_PROVIDER = "openai";
      VISION_LLM_MODEL = "glm-ocr-f16";
      # Cap OCR-generated output length; prevents runaway vision calls.
      VISION_LLM_MAX_TOKENS = "2048";
      TZ = "America/Chicago";
      LOG_LEVEL = "info";
    };
    environmentFiles = [
      config.sops.secrets.paperless-ai-env.path
    ];
    volumes = [
      # Persistent prompts directory (user customizations saved here)
      "/var/lib/paperless-gpt/prompts:/app/prompts"
      # Persistent config directory (settings.json saved here)
      "/var/lib/paperless-gpt/config:/app/config"
    ];
    # Use host networking so the container listens on the host stack directly;
    extraOptions = [ "--network=host" ];
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "paperless-gpt.homehub.tv";
    port = 28983; # container listens here via LISTEN_INTERFACE on the host stack
    proxyWebsockets = true;
  };
}
