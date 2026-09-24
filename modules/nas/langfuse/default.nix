{
  config,
  pkgs,
  lib,
  mkNginxVhost,
  ...
}:

{
  sops.secrets."langfuse-env" = { };

  # Persistent data — explicit bind mounts under /mnt/appdata/langfuse, not
  # opaque named volumes. Ownership matches each image's runtime UID:
  #   postgres -> 999:999   clickhouse -> 101:101   redis -> 999:999
  #   minio -> world-writable: the Chainguard minio runtime UID is
  #                image-dependent; 0777 keeps it writable regardless. Tighten
  #                to the image UID (see `docker inspect`) after first run.
  systemd.tmpfiles.rules = [
    "d /mnt/appdata/langfuse 0755 root root -"
    "d /mnt/appdata/langfuse/postgres 0700 999 999 -"
    "d /mnt/appdata/langfuse/clickhouse 0700 101 101 -"
    "d /mnt/appdata/langfuse/clickhouse-logs 0700 101 101 -"
    "d /mnt/appdata/langfuse/redis 0700 999 999 -"
    "d /mnt/appdata/langfuse/minio 0777 root root -"
  ];

  # Isolated docker network. compose2nix cannot encode health-based depends_on;
  # we use systemd After/Requires (see containers' dependsOn + this network
  # unit) and rely on Langfuse's own retry/backoff for cross-service readiness.
  # Residual behavior is documented in the NAS README "Langfuse" section.
  systemd.services =
    (lib.genAttrs
      (map (n: "docker-${n}") [
        "langfuse-web"
        "langfuse-worker"
        "postgres"
        "clickhouse"
        "minio"
        "redis"
      ])
      (_: {
        after = [ "docker-network-langfuse.service" ];
        requires = [ "docker-network-langfuse.service" ];
      })
    )
    // {
      docker-network-langfuse = {
        path = [ pkgs.docker ];
        after = [
          "docker.service"
          "docker.socket"
        ];
        requires = [ "docker.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "docker network rm -f langfuse";
        };
        script = ''
          docker network inspect langfuse >/dev/null 2>&1 || docker network create langfuse
        '';
        wantedBy = [ "multi-user.target" ];
      };
    };

  # Shared non-secret environment for web + worker. Every value here is also
  # present verbatim in the upstream compose default; secrets live only in the
  # SOPS env file.
  virtualisation.oci-containers.containers =
    let
      commonEnv = {
        # LLM connection base URLs are SSRF-checked separately.
        # LANGFUSE_UNSAFE_TRUSTED_PRIVATE_IPS does not open them (upstream
        # #13097; live 4.15 still returns "Blocked IP address detected").
        # Host allowlist short-circuits the IP check. Containers reach
        # llama-swap via host.docker.internal, never 127.0.0.1.
        LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST = "host.docker.internal";
        LANGFUSE_LLM_CONNECTION_WHITELISTED_IPS = "172.18.0.1,172.17.0.1,192.168.1.2";

        NEXTAUTH_URL = "https://langfuse.homehub.tv";
        TELEMETRY_ENABLED = "true";
        LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES = "false";
        CLICKHOUSE_MIGRATION_URL = "clickhouse://clickhouse:9000";
        CLICKHOUSE_URL = "http://clickhouse:8123";
        CLICKHOUSE_USER = "clickhouse";
        CLICKHOUSE_CLUSTER_ENABLED = "false";
        LANGFUSE_S3_EVENT_UPLOAD_BUCKET = "langfuse";
        LANGFUSE_S3_EVENT_UPLOAD_REGION = "auto";
        LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID = "minio";
        LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT = "http://minio:9000";
        LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE = "true";
        LANGFUSE_S3_EVENT_UPLOAD_PREFIX = "events/";
        LANGFUSE_S3_MEDIA_UPLOAD_BUCKET = "langfuse";
        LANGFUSE_S3_MEDIA_UPLOAD_REGION = "auto";
        LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID = "minio";
        LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT = "http://minio:9000";
        LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE = "true";
        LANGFUSE_S3_MEDIA_UPLOAD_PREFIX = "media/";
        LANGFUSE_S3_BATCH_EXPORT_BUCKET = "langfuse";
        LANGFUSE_S3_BATCH_EXPORT_PREFIX = "exports/";
        LANGFUSE_S3_BATCH_EXPORT_REGION = "auto";
        LANGFUSE_S3_BATCH_EXPORT_ENDPOINT = "http://minio:9000";
        LANGFUSE_S3_BATCH_EXPORT_EXTERNAL_ENDPOINT = "http://localhost:9090";
        LANGFUSE_S3_BATCH_EXPORT_ACCESS_KEY_ID = "minio";
        LANGFUSE_S3_BATCH_EXPORT_FORCE_PATH_STYLE = "true";
        LANGFUSE_USE_AZURE_BLOB = "false";
        LANGFUSE_USE_OCI_NATIVE_OBJECT_STORAGE = "false";
        REDIS_HOST = "redis";
        REDIS_PORT = "6379";
        REDIS_TLS_ENABLED = "false";
      };
      langfuseEnvFile = config.sops.secrets."langfuse-env".path;
    in
    {
      "langfuse-web" = {
        autoStart = true;
        image = "docker.langfuse.com/langfuse/langfuse:4";
        environment = commonEnv;
        environmentFiles = [ langfuseEnvFile ];
        ports = [ "127.0.0.1:3000:3000" ];
        dependsOn = [
          "postgres"
          "redis"
          "minio"
          "clickhouse"
        ];
        extraOptions = [
          "--network=langfuse"
          "--network-alias=langfuse-web"
          "--add-host=host.docker.internal:host-gateway"
        ];
        log-driver = "journald";
      };

      "langfuse-worker" = {
        autoStart = true;
        image = "docker.langfuse.com/langfuse/langfuse-worker:4";
        environment = commonEnv;
        environmentFiles = [ langfuseEnvFile ];
        dependsOn = [
          "postgres"
          "redis"
          "minio"
          "clickhouse"
        ];
        extraOptions = [
          "--network=langfuse"
          "--network-alias=langfuse-worker"
          "--add-host=host.docker.internal:host-gateway"
        ];
        log-driver = "journald";
      };

      "postgres" = {
        autoStart = true;
        image = "docker.io/postgres:17";
        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_DB = "postgres";
          TZ = "UTC";
          PGTZ = "UTC";
        };
        environmentFiles = [ langfuseEnvFile ];
        volumes = [ "/mnt/appdata/langfuse/postgres:/var/lib/postgresql/data" ];
        extraOptions = [
          "--network=langfuse"
          "--network-alias=postgres"
        ];
        log-driver = "journald";
      };

      "clickhouse" = {
        autoStart = true;
        image = "docker.io/clickhouse/clickhouse-server:25.12";
        user = "101:101";
        environment = {
          CLICKHOUSE_DB = "default";
          CLICKHOUSE_USER = "clickhouse";
        };
        environmentFiles = [ langfuseEnvFile ];
        volumes = [
          "/mnt/appdata/langfuse/clickhouse:/var/lib/clickhouse"
          "/mnt/appdata/langfuse/clickhouse-logs:/var/log/clickhouse-server"
        ];
        extraOptions = [
          "--network=langfuse"
          "--network-alias=clickhouse"
        ];
        log-driver = "journald";
      };

      "minio" = {
        autoStart = true;
        image = "cgr.dev/chainguard/minio";
        entrypoint = "sh";
        # Create the upstream default bucket before making MinIO available.
        cmd = [
          "-c"
          ''
            minio server --address :9000 --console-address :9001 /data &
            server_pid=$!
            until mc alias set local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do sleep 1; done
            mc mb --ignore-existing local/langfuse
            wait "$server_pid"
          ''
        ];
        environmentFiles = [ langfuseEnvFile ];
        volumes = [ "/mnt/appdata/langfuse/minio:/data" ];
        extraOptions = [
          "--network=langfuse"
          "--network-alias=minio"
        ];
        log-driver = "journald";
      };

      "redis" = {
        autoStart = true;
        image = "docker.io/redis:7";
        # Password comes from the SOPS env file (REDIS_AUTH); expand it at runtime
        # so the secret is never written to the Nix store.
        entrypoint = "sh";
        cmd = [
          "-c"
          "exec redis-server --requirepass \"$REDIS_AUTH\" --maxmemory-policy noeviction"
        ];
        environmentFiles = [ langfuseEnvFile ];
        volumes = [ "/mnt/appdata/langfuse/redis:/data" ];
        extraOptions = [
          "--network=langfuse"
          "--network-alias=redis"
        ];
        log-driver = "journald";
      };
    };

  # Nginx ingress: only the web service is exposed to the host (on localhost),
  # proxied here. Internal dependency ports are NOT published (see above).
  services.nginx.virtualHosts = mkNginxVhost {
    host = "langfuse.homehub.tv";
    port = 3000;
    proxyWebsockets = true;
    locationExtraConfig = ''
      client_max_body_size 256m;
      proxy_buffering off;
    '';
  };
}
