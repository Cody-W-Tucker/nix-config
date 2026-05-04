{ pkgs, ... }:

{
  # Docker is still used for Open WebUI pipelines.
  virtualisation = {
    docker = {
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
    oci-containers.backend = "docker";
    oci-containers.containers = {
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
  };
  # Local AI models
  services = {
    open-webui = {
      enable = true;
      package = pkgs.open-webui.overridePythonAttrs (oldAttrs: {
        dependencies = oldAttrs.dependencies ++ [ pkgs.python313Packages.qdrant-client ];
      });
      host = "0.0.0.0";
      port = 8080;
      stateDir = "/var/lib/open-webui";
      openFirewall = true;
      environment = {
        WEBUI_URL = "https://ai.homehub.tv";
        WEBUI_SECRET_KEY = "local-only";

        # Vector DB
        VECTOR_DB = "qdrant";
        QDRANT_URI = "http://localhost:6333";
        ENABLE_QDRANT_MULTITENANCY_MODE = "True";
        QDRANT_ON_DISK = "True";

        # Content Extraction
        CONTENT_EXTRACTION_ENGINE = "tika";
        TIKA_SERVER_URL = "https://tika.homehub.tv";

        # RAG
        ENABLE_RAG_HYBRID_SEARCH = "True";

        # Speech to Text
        WHISPER_MODEL = "base";
        WHISPER_VAD_FILTER = "True";
      };
    };
    tika = {
      # Content extraction
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
  # Make the pipelines dir
  systemd.tmpfiles.rules = [
    "d /var/lib/pipelines 0755 root root - -"
  ];
  systemd.services."docker-pipelines".requires = [ "docker.service" ];

  # Since we run open-webui on beast and the nginx server is on the server, we must open the port so the web server can proxy them
  networking.firewall.allowedTCPPorts = [
    8080
    6333
  ];
}
