{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.karakeep ];

  den.aspects.karakeep.nixos =
    {
      config,
      mkNginxVhost,
      pkgs,
      ...
    }:
    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Karakeep = {
        group = "Tools";
        order = 60;
        card = {
          href = "https://karakeep.${domain}";
          icon = "karakeep";
          description = "Bookmark Manager";
        };
      };

      services.karakeep = {
        enable = true;
        package = pkgs.unstable.karakeep;
        extraEnvironment = {
          PORT = "3005";
          DB_WAL_MODE = "true";
          DISABLE_SIGNUPS = "true";
          DISABLE_NEW_RELEASE_CHECK = "true";
          OPENAI_BASE_URL = "http://127.0.0.1:8081/v1";
          OPENAI_API_KEY = "sk-llama-swap";

          INFERENCE_TEXT_MODEL = "qwen-3.5-4b";
          OCR_USE_LLM = "true";
          INFERENCE_IMAGE_MODEL = "qwen-3.5-4b";
          INFERENCE_CONTEXT_LENGTH = "24576";
          INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";

          EMBEDDING_ENABLE_AUTO_INDEXING = "true";
          EMBEDDING_TEXT_MODEL = "qwen3-embedding-0.6b";
          EMBEDDING_DIMENSIONS = "1024";
          EMBEDDING_CONTEXT_LENGTH = "8192";
          MAX_ASSET_SIZE_MB = "100";
        };
      };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "karakeep.${domain}";
        port = 3005;
        proxyWebsockets = true;
      };

      nas.backups.sqlite = [
        {
          name = "karakeep";
          source = "/var/lib/karakeep/db.db";
          filename = "db.db";
        }
      ];
      nas.backups.dataDirectories = [
        "/var/lib/karakeep/assets"
        "/var/lib/karakeep/settings.env"
      ];
    };
}
