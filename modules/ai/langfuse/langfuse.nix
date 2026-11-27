{ den, ... }:
{
  den.aspects.nas.includes = [ den.aspects.langfuse ];

  den.aspects.langfuse.nixos =
    {
      config,
      pkgs,
      lib,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.Langfuse = {
        group = "Business";
        order = 20;
        card = {
          href = "https://langfuse.${domain}";
          icon = "https://langfuse.${domain}/favicon.ico";
          description = "LLM Observability";
        };
      };

      imports = [
        ./_review-queue.nix
        ./_backups.nix
      ];

      sops.secrets."langfuse-env" = { };

      systemd.tmpfiles.rules = [
        "d /mnt/appdata/langfuse 0755 root root -"
        "d /mnt/appdata/langfuse/postgres 0700 999 999 -"
        "d /mnt/appdata/langfuse/clickhouse 0700 101 101 -"
        "d /mnt/appdata/langfuse/clickhouse-logs 0700 101 101 -"
        "d /mnt/appdata/langfuse/redis 0700 999 999 -"
        "d /mnt/appdata/langfuse/minio 0777 root root -"
      ];

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

      virtualisation.oci-containers.containers =
        let
          commonEnv = {
            LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST = "host.docker.internal";
            LANGFUSE_LLM_CONNECTION_WHITELISTED_IPS = "172.18.0.1,172.17.0.1,${config.codyos.site.hosts.nas.lan}";

            NEXTAUTH_URL = "https://langfuse.${domain}";
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
            image = "docker.langfuse.com/langfuse/langfuse:4.68.0";
            environment = commonEnv;
            environmentFiles = [ langfuseEnvFile ];
            ports = [ "127.0.0.1:3030:3000" ];
            dependsOn = [
              "postgres"
              "redis"
              "minio"
              "clickhouse"
            ];
            networks = [ "langfuse" ];
            extraOptions = [
              "--network-alias=langfuse-web"
              "--add-host=host.docker.internal:host-gateway"
            ];
          };

          "langfuse-worker" = {
            image = "docker.langfuse.com/langfuse/langfuse-worker:4.68.0";
            environment = commonEnv;
            environmentFiles = [ langfuseEnvFile ];
            dependsOn = [
              "postgres"
              "redis"
              "minio"
              "clickhouse"
            ];
            networks = [ "langfuse" ];
            extraOptions = [
              "--network-alias=langfuse-worker"
              "--add-host=host.docker.internal:host-gateway"
            ];
          };

          "postgres" = {
            image = "docker.io/postgres:17";
            environment = {
              POSTGRES_USER = "postgres";
              POSTGRES_DB = "postgres";
              TZ = "UTC";
              PGTZ = "UTC";
            };
            environmentFiles = [ langfuseEnvFile ];
            volumes = [ "/mnt/appdata/langfuse/postgres:/var/lib/postgresql/data" ];
            networks = [ "langfuse" ];
            extraOptions = [
              "--network-alias=postgres"
            ];
          };

          "clickhouse" = {
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
            networks = [ "langfuse" ];
            extraOptions = [
              "--network-alias=clickhouse"
            ];
          };

          "minio" = {
            image = "cgr.dev/chainguard/minio";
            entrypoint = "sh";
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
            networks = [ "langfuse" ];
            extraOptions = [
              "--network-alias=minio"
            ];
          };

          "redis" = {
            image = "docker.io/redis:7";
            entrypoint = "sh";
            cmd = [
              "-c"
              "exec redis-server --requirepass \"$REDIS_AUTH\" --maxmemory-policy noeviction"
            ];
            environmentFiles = [ langfuseEnvFile ];
            volumes = [ "/mnt/appdata/langfuse/redis:/data" ];
            networks = [ "langfuse" ];
            extraOptions = [
              "--network-alias=redis"
            ];
          };
        };

      services.nginx.virtualHosts = mkNginxVhost {
        host = "langfuse.${domain}";
        port = 3030;
        proxyWebsockets = true;
        locationExtraConfig = ''
          client_max_body_size 256m;
          proxy_buffering off;
        '';
      };
    };
}
