{ config, pkgs, ... }:
{
  # Declare the secret
  sops.secrets."SEARXNG_SECRET" = { };

  services.searx = {
    enable = true;
    package = pkgs.searxng;
    redisCreateLocally = true;

    settings = {
      general = {
        debug = false;
        instance_name = "Cody's Search";
        donation_url = false;
        contact_url = false;
        privacypolicy_url = false;
        enable_metrics = false;
      };

      server = {
        port = 8888;
        bind_address = "127.0.0.1";
        base_url = "https://search.homehub.tv";
        limiter = true;
        public_instance = false;
        image_proxy = true;
        secret_key = config.sops.secrets."SEARXNG_SECRET".path;
      };

      ui = {
        static_use_hash = true;
        default_locale = "en";
        query_in_title = true;
        infinite_scroll = false;
        center_alignment = true;
        default_theme = "simple";
        theme_args.simple_style = "auto";
        search_on_category_select = false;
        hotkeys = "vim";
      };

      search = {
        safe_search = 0;
        autocomplete_min = 2;
        autocomplete = "duckduckgo";
      };

      outgoing = {
        request_timeout = 5.0;
        max_request_timeout = 15.0;
        pool_connections = 100;
        pool_maxsize = 15;
        enable_http2 = true;
      };
    };
  };

  # Nginx reverse proxy
  services.nginx.virtualHosts."search.homehub.tv" = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    kTLS = true;
    locations."/" = {
      proxyPass = "http://localhost:8888";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
}
