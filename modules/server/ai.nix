{ config, pkgs, ... }:

{
  # Ollama local llm
  services = {
    ollama = {
      enable = true;
      port = 11434;
      openFirewall = true;
      host = "0.0.0.0";
    };
    open-webui = {
      enable = true;
      port = 11435;
      host = "0.0.0.0";
      openFirewall = true;
      environment = {
        OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
        # Disable authentication
        WEBUI_AUTH = "False";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        ENABLE_RAG_WEB_SEARCH = "True";
        RAG_WEB_SEARCH_ENGINE = "searxng";
        RAG_WEB_SEARCH_RESULT_COUNT = "3";
        RAG_WEB_SEARCH_CONCURRENT_REQUESTS = "10";
        SEARXNG_QUERY_URL = "http://homehub.tv:8888/search?q=<query>";
      };
    };
    searx = {
      enable = true;
      redisCreateLocally = true;
      limiterSettings = {
        # activate link_token method in the ip_limit method
        link_token = true;
      };
      settings = {
        use_default_settings = true;
        server = {
          port = 8888;
          bind_address = "0.0.0.0";
          secret_key = "secret";
        };
        ui = {
          static_use_hash = true;
        };
        search = {
          formats = {
            html = true;
            json = true;
          };
        };
      };
    };
  };
  networking.firewall.allowedTCPPorts = [ 8888 ];
}
