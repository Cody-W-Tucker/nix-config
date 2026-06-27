{ pkgs, ... }:

let
  openWebuiPackage = pkgs.open-webui.overridePythonAttrs (oldAttrs: {
    dependencies = oldAttrs.dependencies ++ [ pkgs.python313Packages.qdrant-client ];
  });
in

{
  # Local AI models
  services = {
    open-webui = {
      enable = true;
      package = openWebuiPackage;
      host = "0.0.0.0";
      port = 8080;
      stateDir = "/var/lib/open-webui";
      openFirewall = true;
      environment = {
        HOME = "/var/lib/open-webui";

        # TODO: make all this declarative instead of having to configure in the admin panel.
        # ENABLE_PERSISTENT_CONFIG = "False"
        WEBUI_URL = "https://ai.homehub.tv";
        WEBUI_SECRET_KEY = "local-only";
        USE_CUDA_DOCKER = "true";

        # Vector DB
        VECTOR_DB = "qdrant";
        QDRANT_URI = "http://localhost:6333";
        ENABLE_QDRANT_MULTITENANCY_MODE = "True";
        QDRANT_ON_DISK = "True";

        # Content Extraction
        CONTENT_EXTRACTION_ENGINE = "tika";
        TIKA_SERVER_URL = "http://localhost:9998";

        # RAG
        ENABLE_RAG_HYBRID_SEARCH = "True";
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
  # Since we run open-webui on beast and the nginx server is on the server, we must open the port so the web server can proxy them
  networking.firewall.allowedTCPPorts = [
    8080
    6333
  ];
}
