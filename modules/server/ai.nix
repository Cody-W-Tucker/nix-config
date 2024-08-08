{ config, ... }:
let userDir = "${config.users.users.codyt.home}";
in
{
  # docker run --name open-webui --network=host -e PORT=11435 -e OLLAMA_BASE_URL=http://192.168.254.25:11434 -v ~/open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main
  virtualisation.oci-containers.containers."open-webui" = {
    autoStart = true;
    image = "ghcr.io/open-webui/open-webui:main";
    ports = [ "3000:8080" ];
    volumes = [ "${userDir}/open-webui:/app/backend/data" "${userDir}/RAG-Docs:${userDir}/RAG-Docs" ];
    extraOptions = [ "--network=host" ];
    environment = {
      OLLAMA_BASE_URL = "http://192.168.254.25:11434";
      # Disable authentication
      WEBUI_AUTH = "False";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      USER_AGENT = "Ollama";
      AIOHTTP_CLIENT_TIMEOUT = "600";
      ENABLE_RAG_WEB_SEARCH = "True";
      RAG_WEB_SEARCH_ENGINE = "searxng";
      SEARXNG_QUERY_URL = "https://search.homehub.tv/search?q=<query>";
      ENABLE_RAG_HYBRID_SEARCH = "True";
      DOCS_DIR = "${userDir}/RAG-Docs";
    };
  };
  fileSystems."/home/codyt/RAG-Docs" = {
    device = "/mnt/hdd/Share/Documents/RAG-Docs";
    fsType = "none";
    options = [ "bind" "rw" ];
  };
  # Ollama local llm
  services = {
    nginx.virtualHosts = {
      "search.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8888";
          proxyWebsockets = true;
        };
      };
      "ai.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
        };
      };
    };
    ollama = {
      enable = true;
      port = 11434;
      openFirewall = true;
      host = "0.0.0.0";
    };
    # open-webui = {
    #   enable = true;
    #   port = 11435;
    #   host = "127.0.0.1";
    #   openFirewall = false;
    #   environment = {
    #     OLLAMA_API_BASE_URL = "http://192.168.254.25:11434";
    #     # Disable authentication
    #     WEBUI_AUTH = "False";
    #     ANONYMIZED_TELEMETRY = "False";
    #     DO_NOT_TRACK = "True";
    #     SCARF_NO_ANALYTICS = "True";
    #     SEARXNG_QUERY_URL = "https://search.homehub.tv/search?q=<query>";
    #     USER_AGENT = "Ollama";
    #     ENABLE_RAG_WEB_LOADER_SSL_VERIFICATION = "False";
    #     AIOHTTP_CLIENT_TIMEOUT = "600";
    #   };
    # };
    searx = {
      enable = true;
      redisCreateLocally = true;
      settings = {
        use_default_settings = true;
        outgoing = {
          request_timeout = 15.0;
          max_request_timeout = 30.0;
        };
        server = {
          base_url = "http://search.homehub.tv:8888";
          port = 8888;
          bind_address = "0.0.0.0";
          secret_key = "secret";
          limiter = false;
          image_proxy = false;
        };
        ui = {
          static_use_hash = true;
        };
        search = {
          safe_search = 0;
          autocomplete = "";
          default_lang = "";
          formats = [ "html" "json" ];
        };
        outgoing = {
          useragent_suffix = "webdev@tmvsocial.com";
        };
      };
    };
  };
}
