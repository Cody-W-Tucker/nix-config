{ config, pkgs, ... }:

{
  # Ollama local llm
  services = {
    nginx.virtualHosts = {
      "ai.homehub.tv" = {
        enableACME = false;
        forceSSL = false;
        locations."/" = {
          proxyPass = "http://ai.homehub.tv:11435";
          proxyWebsockets = true;
        };
      };
      "search.homehub.tv" = {
        enableACME = false;
        forceSSL = false;
        locations."/" = {
          proxyPass = "http://search.homehub.tv:8888";
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
    open-webui = {
      enable = true;
      port = 11435;
      host = "0.0.0.0";
      openFirewall = true;
      environment = {
        OLLAMA_API_BASE_URL = "http://192.168.254.25:11434";
        # Disable authentication
        WEBUI_AUTH = "False";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        SEARXNG_QUERY_URL = "http://homehub.tv:8888/search?q=<query>";
        USER_AGENT = "Ollama";
        CHROMA_HTTP_PORT = "11436";
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
          limiter = false;
          image_proxy = true;
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
  networking.firewall.allowedTCPPorts = [ 8888 11436 ];
}
