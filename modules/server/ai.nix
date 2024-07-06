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
        SEARXNG_QUERY_URL = "http://homehub.tv:8888/search?q=<query>";
      };
    };
    searx = {
      enable = true;
      redisCreateLocally = true;
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
          safe_search = 0;
          autocomplete = "";
          default_lang = "";
          formats = [ "html" "json" ];
        };
      };
    };
  };
  networking.firewall.allowedTCPPorts = [ 8888 ];
}
