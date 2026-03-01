{ pkgs, ... }:

{
  # Enable CUDA in containers
  hardware.nvidia-container-toolkit.enable = true;

  # Docker
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers = {
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
      extraOptions = [
        "--add-host=host.docker.internal:host-gateway"
        "--network=host"
        "--pull=always"
      ];
    };
  };
  # Local AI models
  services = {
    ollama = {
      enable = true;
      package = pkgs.ollama-cuda.override {
        # nvidia-smi --query-gpu=compute_cap --format=csv
        cudaArches = [ "86" ];
      };
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
  };
  # Make the open-webui and pipelines dirs
  systemd.tmpfiles.rules = [
    "d /var/lib/open-webui 0755 root root - -"
    "d /var/lib/pipelines 0755 root root - -"
  ];
  # Since we run open-webui on beast and the nginx server is on the server, we must open the port so the web server can proxy them
  networking.firewall.allowedTCPPorts = [
    8080
  ];
}
