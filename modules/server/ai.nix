{ config, ... }:
let userDir = "${config.users.users.codyt.home}";
in
{
  virtualisation.oci-containers.containers = {
    # docker run --name open-webui --add-host=host.docker.internal:host-gateway -e PORT=11435 -e OLLAMA_BASE_URL=http://server:11434 -v ~/open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main
    "open-webui" = {
      autoStart = true;
      image = "ghcr.io/open-webui/open-webui:main";
      ports = [ "3030:8080" ];
      volumes = [ "${userDir}/open-webui:/app/backend/data" ];
      extraOptions = [
        "--pull=always"
        "--add-host=host.docker.internal:host-gateway"
        "--network=host"
      ];
      environment = {
        OLLAMA_BASE_URL = "http://server:11434";
        WEBUI_URL = "https://ai.homehub.tv";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        USER_AGENT = "Ollama";
        AIOHTTP_CLIENT_TIMEOUT = "";
        ENABLE_RAG_WEB_SEARCH = "True";
        RAG_WEB_SEARCH_ENGINE = "searxng";
        SEARXNG_QUERY_URL = "https://search.homehub.tv/search?q=<query>";
        ENABLE_RAG_HYBRID_SEARCH = "True";
      };
    };
    # docker run -d -p 9099:9099 --add-host=host.docker.internal:host-gateway -v pipelines:/app/pipelines --name pipelines --restart always ghcr.io/open-webui/pipelines:main
    "pipelines" = {
      autoStart = true;
      image = "ghcr.io/open-webui/pipelines:main";
      ports = [ "9099:9099" ];
      volumes = [ "${userDir}/pipelines:/app/pipelines" ];
      extraOptions = [ "--add-host=host.docker.internal:host-gateway" "--pull=always" ];
    };
  };
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
      "qdrant.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://localhost:6333";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $remote_addr;
          '';
        };
      };
    };
    # Local AI models
    ollama = {
      enable = true;
      port = 11434;
      openFirewall = true;
      host = "0.0.0.0";
    };
    # Content extraction
    tika = {
      enable = true;
      port = 9998;
    };
    # Vector Search http port 6333, gRPC port 6334
    qdrant = {
      enable = true;
    };
    # Search engine
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
