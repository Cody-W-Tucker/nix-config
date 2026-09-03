{
  inputs,
  mkNginxVhost,
  pkgs,
  ...
}:

{
  # ── Open WebUI (local AI chat interface) ───────────────────────
  services = {
    open-webui = {
      enable = true;
      package = pkgs.open-webui.overridePythonAttrs (oldAttrs: {
        dependencies = oldAttrs.dependencies ++ [ pkgs.python3Packages.qdrant-client ];
      });
      host = "0.0.0.0";
      port = 8080;
      stateDir = "/var/lib/open-webui";
      openFirewall = true;
      environment = {
        HOME = "/var/lib/open-webui";

        # TODO: make all this declarative instead of having to configure in the admin panel.
        # ENABLE_PERSISTENT_CONFIG = "False"
        WEBUI_URL = "https://chat.homehub.tv";
        WEBUI_SECRET_KEY = "local-only";
        USE_CUDA_DOCKER = "true";

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
      };
    };
    qdrant = {
      enable = true;
      package = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.qdrant;
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
    nginx.virtualHosts =
      (mkNginxVhost {
        host = "qdrant.homehub.tv";
        locations = {
          # HTTP API (REST API on port 6333)
          "/" = {
            proxyPass = "http://localhost:6333";
          };
          # gRPC API (on port 6334)
          "/grpc" = {
            proxyPass = "http://localhost:6334";
            extraConfig = ''
              grpc_set_header Host $host;
              grpc_set_header X-Real-IP $remote_addr;
              grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              grpc_pass grpc://localhost:6334;
            '';
          };
        };
      })
      // (mkNginxVhost {
        host = "chat.homehub.tv";
        port = 8080;
        proxyWebsockets = true;
        locationExtraConfig = ''
          proxy_buffering off;
          client_max_body_size 256m;
        '';
      });
  };
}
