{
  # Enable CUDA in containers
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.oci-containers.containers = {
    # docker run --name open-webui --add-host=host.docker.internal:host-gateway -e PORT=11435 -e OLLAMA_BASE_URL=http://server:11434 -v ~/open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main
    "open-webui" = {
      autoStart = true;
      image = "ghcr.io/open-webui/open-webui:cuda";
      ports = [ "8080:8080" ];
      volumes = [ "/var/lib/open-webui:/app/backend/data" ];
      extraOptions = [
        "--pull=always"
        "--add-host=host.docker.internal:host-gateway"
        "--network=host"
        "--device=nvidia.com/gpu=all"
      ];
      environment = {
        WEBUI_URL = "https://ai.homehub.tv";
        ANONYMIZED_TELEMETRY = "False";
        DO_NOT_TRACK = "True";
        SCARF_NO_ANALYTICS = "True";
        WEBUI_SECRET_KEY = "local-only";
        USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.3";

        # Local AI
        OLLAMA_BASE_URL = "http://localhost:11434";
        USE_CUDA_DOCKER = "True";

        # Vector DB
        VECTOR_DB = "qdrant";
        QDRANT_URI = "http://localhost:6333";
        ENABLE_QDRANT_MULTITENANCY_MODE = "True";
        QDRANT_ON_DISK = "True";

        # Content Extraction
        CONTENT_EXTRACTION_ENGINE = "tika";
        TIKA_SERVER_URL = "https://tika.homehub.tv";

        # RAG
        RAG_EMBEDDING_ENGINE = "ollama";
        RAG_EMBEDDING_MODEL = "nomic-embed-text";
        ENABLE_RAG_HYBRID_SEARCH = "True";

        # Speech to Text
        WHISPER_MODEL = "base";
        WHISPER_VAD_FILTER = "True";
      };
    };
    # docker run -d -p 9099:9099 --add-host=host.docker.internal:host-gateway -v pipelines:/app/pipelines --name pipelines --restart always ghcr.io/open-webui/pipelines:main
    "pipelines" = {
      autoStart = true;
      image = "ghcr.io/open-webui/pipelines:main";
      ports = [ "9099:9099" ];
      volumes = [ "/var/lib/pipelines/pipelines:/app/pipelines" ];
      extraOptions = [ "--add-host=host.docker.internal:host-gateway" "--network=host" "--pull=always" ];
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
      OnCalendar = "Mon *-*-* 02:00:00";
      RandomizedDelaySec = "2h";
      Persistent = true;
      WakeSystem = true;
    };
  };
  # Local AI models
  services = {
    ollama = {
      enable = true;
      port = 11434;
      openFirewall = true;
      acceleration = "cuda";
      host = "0.0.0.0";
    };
    # Content extraction
    tika = {
      enable = true;
      port = 9998;
      openFirewall = true;
      listenAddress = "0.0.0.0";
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
    qdrant-upload = {
      # Enable auto uploads daily at 2 AM
      enable = true;

      # Service URLs
      qdrantUrl = "http://localhost:6333";
      ollamaUrl = "http://localhost:11434";

      # Performance (RTX 3070 optimized)
      batchSize = 2000;
      maxConcurrent = 4;
      asyncChat = true;

      sources = [
        {
          name = "personal";
          type = "obsidian";
          collection = "personal";
          directories = [
            "/home/codyt/Documents/Personal/Journal"
            "/home/codyt/Documents/Personal/Knowledge"
          ];
          skipExisting = true;
        }
        {
          name = "projects";
          type = "obsidian";
          collection = "projects";
          directories = [ "/home/codyt/Documents/Personal/Projects" ];
        }
        {
          name = "inbox";
          type = "obsidian";
          collection = "inbox";
          directories = [ "/home/codyt/Documents/Personal/Inbox" ];
        }
        {
          name = "entities";
          type = "obsidian";
          collection = "entities";
          directories = [ "/home/codyt/Documents/Personal/Entities" ];
        }
        {
          name = "research";
          type = "obsidian";
          collection = "research";
          directories = [ "/home/codyt/Documents/Personal/Research" ];
        }
      ];
    };
  };
  # Make the open-webui and pipelines dirs
  systemd.tmpfiles.rules = [
    "d /var/lib/open-webui 0755 root root - -"
    "d /var/lib/pipelines 0755 root root - -"
  ];
  # Open the ports so the web server can proxy them
  networking.firewall.allowedTCPPorts = [ 6333 6334 8080 ];
}
