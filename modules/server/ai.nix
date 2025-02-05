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
        RAG_RERANKING_MODEL = "";
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
  # Service to keep open-webui updated
  systemd.services.restart-open-webui = {
    description = "Restart open-webui service";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "systemctl restart docker-open-webui.service";
    };
  };
  systemd.timers.restart-open-webui = {
    wantedBy = [ "timers.target" ];
    partOf = [ "restart-open-webui.service" ];
    timerConfig = {
      OnCalendar = "*-*-* 02:00:00";
      RandomizedDelaySec = "2h";
      Persistent = true;
    };
  };
  # Opening ports for Qdrant, since I'm not sure how to make grpc work with Nginx 
  networking.firewall.allowedTCPPorts = [ 6333 6334 ];
  services = {
    nginx.virtualHosts = {
      "qdrant.homehub.tv" = {
        useACMEHost = "homehub.tv";
        forceSSL = true;
        # HTTP API (REST API on port 6333)
        locations."/" = {
          proxyPass = "http://127.0.0.1:6333"; # Forward REST traffic
          proxyWebsockets = true; # Extra flexibility for WebSockets (not required for REST API)
          # Optional: Add headers to preserve proxy context
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          '';
        };
        # gRPC API (on port 6334)
        locations."/grpc" = {
          proxyPass = "http://127.0.0.1:6334"; # Forward gRPC traffic
          extraConfig = ''
            grpc_set_header Host $host;
            grpc_set_header X-Real-IP $remote_addr;
            grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            grpc_pass grpc://127.0.0.1:6334;    # Ensure grpc_pass for gRPC-specific handling
          '';
        };
      };
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
      settings = {
        storage = {
          storage_path = "/var/lib/qdrant/storage";
          snapshots_path = "/var/lib/qdrant/snapshots";
        };
        hsnw_index = {
          on_disk = true;
        };
        service = {
          host = "0.0.0.0";
          http_port = 6333;
          grpc_port = 6334;
        };
        telemetry_disabled = true;
      };
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
