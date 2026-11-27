{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.paperless-gpt ];

  den.aspects.paperless-gpt.nixos =
    {
      mkNginxVhost,
      config,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.PaperlessGPT = {
        group = "Collect";
        order = 50;
        card = {
          href = "https://paperless-gpt.${domain}";
          icon = "https://paperless-gpt.${domain}/favicon.ico";
          description = "AI Document Assistant";
        };
      };

      nas.backups.dataDirectories = [
        "/var/lib/paperless-gpt/prompts"
        "/var/lib/paperless-gpt/config"
      ];

      sops.secrets."paperless-ai-env" = { };

      systemd.tmpfiles.rules = [
        "d /var/lib/paperless-gpt 0755 root root -"
        "d /var/lib/paperless-gpt/prompts 0755 10001 10001 -"
        "d /var/lib/paperless-gpt/config 0755 10001 10001 -"
      ];

      virtualisation.oci-containers.containers.paperless-gpt = {
        image = "icereed/paperless-gpt:latest";
        environment = {
          PAPERLESS_BASE_URL = "http://127.0.0.1:28981";
          LISTEN_INTERFACE = ":28983";
          LLM_PROVIDER = "openai";
          OPENAI_BASE_URL = "http://127.0.0.1:8081/v1";
          OPENAI_API_KEY = "sk-llama-swap";
          LLM_MODEL = "qwen-3.5-9b";
          OCR_PROVIDER = "llm";
          VISION_LLM_PROVIDER = "openai";
          VISION_LLM_MODEL = "glm-ocr-f16";
          VISION_LLM_MAX_TOKENS = "2048";
          TZ = config.time.timeZone;
          LOG_LEVEL = "info";
          AUTO_GENERATE_TAGS = "false";
          AUTO_GENERATE_DOCUMENT_TYPE = "false";
        };
        environmentFiles = [
          config.sops.secrets.paperless-ai-env.path
        ];
        volumes = [
          "/var/lib/paperless-gpt/prompts:/app/prompts"
          "/var/lib/paperless-gpt/config:/app/config"
        ];
        extraOptions = [ "--network=host" ];
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "paperless-gpt.${domain}";
        port = 28983;
        proxyWebsockets = true;
      };
    };
}
