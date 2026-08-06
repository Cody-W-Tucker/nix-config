{
  mkNginxVhost,
  config,
  ...
}:

{
  # Env file containing PAPERLESS_API_TOKEN.
  # User populates via: sops edit /etc/nixos/secrets/secrets.yaml
  # Expected format (plain KEY=VALUE lines):
  #   PAPERLESS_API_TOKEN=<token>
  sops.secrets."paperless-ai-env" = { };

  virtualisation.oci-containers.containers.paperless-ai = {
    autoStart = true;
    image = "clusterzx/paperless-ai:latest";
    environment = {
      # With host networking, reach the host's Paperless API directly via localhost.
      PAPERLESS_API_URL = "http://127.0.0.1:28981/api";
      # Upstream server.js honors PAPERLESS_AI_PORT (default 3000).
      PAPERLESS_AI_PORT = "28983";
      AI_PROVIDER = "custom";
      CUSTOM_BASE_URL = "http://nas:8081/v1";
      CUSTOM_MODEL = "qwen-3.5-9b";
      CUSTOM_API_KEY = "opencode";
      TZ = "America/Chicago";
    };
    environmentFiles = [
      config.sops.secrets.paperless-ai-env.path
    ];
    volumes = [
      "/var/lib/paperless-ai/data:/app/data"
    ];
    # Use host networking so the container listens on the host stack directly;
    # PAPERLESS_AI_PORT (set above) chooses the listening port.
    extraOptions = [ "--network=host" ];
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "paperless-ai.homehub.tv";
    port = 28983; # container listens here via PAPERLESS_AI_PORT on the host stack
    proxyWebsockets = true;
  };
}
