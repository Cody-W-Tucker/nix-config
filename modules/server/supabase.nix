# Auto-generated using compose2nix v0.3.2-pre.
{ pkgs, lib, config, ... }:

{
  # Enable container name DNS for all docker networks.
  networking.firewall.interfaces =
    let
      matchAll = if !config.networking.nftables.enable then "docker+" else "docker*";
    in
    {
      "${matchAll}".allowedUDPPorts = [ 53 ];
    };

  services.nginx.virtualHosts = {
    "supabase.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://localhost:8123";
      };
    };
  };

  # Containers
  virtualisation.oci-containers.containers."realtime-dev.supabase-realtime" = {
    image = "supabase/realtime:v2.34.47";
    environment = {
      "API_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "APP_NAME" = "realtime";
      "DB_AFTER_CONNECT_QUERY" = "SET search_path TO _realtime";
      "DB_ENC_KEY" = "supabaserealtime";
      "DB_HOST" = "db";
      "DB_NAME" = "postgres";
      "DB_PASSWORD" = "your-super-secret-and-long-postgres-password";
      "DB_PORT" = "5432";
      "DB_USER" = "supabase_admin";
      "DNS_NODES" = "''";
      "ERL_AFLAGS" = "-proto_dist inet_tcp";
      "PORT" = "4000";
      "RLIMIT_NOFILE" = "10000";
      "RUN_JANITOR" = "true";
      "SECRET_KEY_BASE" = "UpNVntn3cDxHJpq99YMc1T1AQgQpc8kfYTuRgBiYa15BLrx8etQoXz3gZv1/u2oq";
      "SEED_SELF_HOST" = "true";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    dependsOn = [
      "supabase-analytics"
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"curl\", \"-sSfL\", \"--head\", \"-o\", \"/dev/null\", \"-H\", \"Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE\", \"http://localhost:4000/api/tenants/realtime-dev/health\"]"
      "--health-interval=5s"
      "--health-retries=3"
      "--health-timeout=5s"
      "--network-alias=realtime"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-realtime-dev.supabase-realtime" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-analytics" = {
    image = "supabase/logflare:1.14.2";
    environment = {
      "DB_DATABASE" = "_supabase";
      "DB_HOSTNAME" = "db";
      "DB_PASSWORD" = "your-super-secret-and-long-postgres-password";
      "DB_PORT" = "5432";
      "DB_SCHEMA" = "_analytics";
      "DB_USERNAME" = "supabase_admin";
      "LOGFLARE_FEATURE_FLAG_OVERRIDE" = "multibackend=true";
      "LOGFLARE_MIN_CLUSTER_SIZE" = "1";
      "LOGFLARE_NODE_HOST" = "127.0.0.1";
      "LOGFLARE_PRIVATE_ACCESS_TOKEN" = "your-super-secret-and-long-logflare-key-private";
      "LOGFLARE_PUBLIC_ACCESS_TOKEN" = "your-super-secret-and-long-logflare-key-public";
      "LOGFLARE_SINGLE_TENANT" = "true";
      "LOGFLARE_SUPABASE_MODE" = "true";
      "POSTGRES_BACKEND_SCHEMA" = "_analytics";
      "POSTGRES_BACKEND_URL" = "postgresql://supabase_admin:your-super-secret-and-long-postgres-password@db:5432/_supabase";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    ports = [
      "4000:4000/tcp"
    ];
    dependsOn = [
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"curl\", \"http://localhost:4000/health\"]"
      "--health-interval=5s"
      "--health-retries=10"
      "--health-timeout=5s"
      "--network-alias=analytics"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-analytics" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-auth" = {
    image = "supabase/gotrue:v2.174.0";
    environment = {
      "API_EXTERNAL_URL" = "http://localhost:8123";
      "GOTRUE_API_HOST" = "0.0.0.0";
      "GOTRUE_API_PORT" = "9999";
      "GOTRUE_DB_DATABASE_URL" = "postgres://supabase_auth_admin:your-super-secret-and-long-postgres-password@db:5432/postgres";
      "GOTRUE_DB_DRIVER" = "postgres";
      "GOTRUE_DISABLE_SIGNUP" = "false";
      "GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED" = "false";
      "GOTRUE_EXTERNAL_EMAIL_ENABLED" = "true";
      "GOTRUE_EXTERNAL_PHONE_ENABLED" = "true";
      "GOTRUE_JWT_ADMIN_ROLES" = "service_role";
      "GOTRUE_JWT_AUD" = "authenticated";
      "GOTRUE_JWT_DEFAULT_GROUP_NAME" = "authenticated";
      "GOTRUE_JWT_EXP" = "3600";
      "GOTRUE_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "GOTRUE_MAILER_AUTOCONFIRM" = "false";
      "GOTRUE_MAILER_URLPATHS_CONFIRMATION" = "/auth/v1/verify";
      "GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE" = "/auth/v1/verify";
      "GOTRUE_MAILER_URLPATHS_INVITE" = "/auth/v1/verify";
      "GOTRUE_MAILER_URLPATHS_RECOVERY" = "/auth/v1/verify";
      "GOTRUE_SITE_URL" = "http://localhost:3000";
      "GOTRUE_SMS_AUTOCONFIRM" = "true";
      "GOTRUE_SMTP_ADMIN_EMAIL" = "admin@example.com";
      "GOTRUE_SMTP_HOST" = "supabase-mail";
      "GOTRUE_SMTP_PASS" = "fake_mail_password";
      "GOTRUE_SMTP_PORT" = "2500";
      "GOTRUE_SMTP_SENDER_NAME" = "fake_sender";
      "GOTRUE_SMTP_USER" = "fake_mail_user";
      "GOTRUE_URI_ALLOW_LIST" = "";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    dependsOn = [
      "supabase-analytics"
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"wget\", \"--no-verbose\", \"--tries=1\", \"--spider\", \"http://localhost:9999/health\"]"
      "--health-interval=5s"
      "--health-retries=3"
      "--health-timeout=5s"
      "--network-alias=auth"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-auth" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-db" = {
    image = "supabase/postgres:15.8.1.060";
    environment = {
      "JWT_EXP" = "3600";
      "JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "PGDATABASE" = "postgres";
      "PGPASSWORD" = "your-super-secret-and-long-postgres-password";
      "PGPORT" = "5432";
      "POSTGRES_DB" = "postgres";
      "POSTGRES_HOST" = "/var/run/postgresql";
      "POSTGRES_PASSWORD" = "your-super-secret-and-long-postgres-password";
      "POSTGRES_PORT" = "5432";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    volumes = [
      "/home/codyt/supabase-docker/volumes/db/_supabase.sql:/docker-entrypoint-initdb.d/migrations/97-_supabase.sql:rw,Z"
      "/home/codyt/supabase-docker/volumes/db/data:/var/lib/postgresql/data:rw,Z"
      "/home/codyt/supabase-docker/volumes/db/jwt.sql:/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql:rw,Z"
      "/home/codyt/supabase-docker/volumes/db/logs.sql:/docker-entrypoint-initdb.d/migrations/99-logs.sql:rw,Z"
      "/home/codyt/supabase-docker/volumes/db/pooler.sql:/docker-entrypoint-initdb.d/migrations/99-pooler.sql:rw,Z"
      "/home/codyt/supabase-docker/volumes/db/realtime.sql:/docker-entrypoint-initdb.d/migrations/99-realtime.sql:rw,Z"
      "/home/codyt/supabase-docker/volumes/db/roles.sql:/docker-entrypoint-initdb.d/init-scripts/99-roles.sql:rw,Z"
      "/home/codyt/supabase-docker/volumes/db/webhooks.sql:/docker-entrypoint-initdb.d/init-scripts/98-webhooks.sql:rw,Z"
      "supabase_db-config:/etc/postgresql-custom:rw"
    ];
    cmd = [ "postgres" "-c" "config_file=/etc/postgresql/postgresql.conf" "-c" "log_min_messages=fatal" ];
    dependsOn = [
      "supabase-vector"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"pg_isready\", \"-U\", \"postgres\", \"-h\", \"localhost\"]"
      "--health-interval=5s"
      "--health-retries=10"
      "--health-timeout=5s"
      "--network-alias=db"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
      "docker-volume-supabase_db-config.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
      "docker-volume-supabase_db-config.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-edge-functions" = {
    image = "supabase/edge-runtime:v1.67.4";
    environment = {
      "JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "SUPABASE_ANON_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE";
      "SUPABASE_DB_URL" = "postgresql://postgres:your-super-secret-and-long-postgres-password@db:5432/postgres";
      "SUPABASE_SERVICE_ROLE_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q";
      "SUPABASE_URL" = "http://kong:8000";
      "VERIFY_JWT" = "false";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    volumes = [
      "/home/codyt/supabase-docker/volumes/functions:/home/deno/functions:rw,Z"
    ];
    cmd = [ "start" "--main-service" "/home/deno/functions/main" ];
    dependsOn = [
      "supabase-analytics"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=functions"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-edge-functions" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-imgproxy" = {
    image = "darthsim/imgproxy:v3.8.0";
    environment = {
      "IMGPROXY_BIND" = ":5001";
      "IMGPROXY_ENABLE_WEBP_DETECTION" = "true";
      "IMGPROXY_LOCAL_FILESYSTEM_ROOT" = "/";
      "IMGPROXY_USE_ETAG" = "true";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    volumes = [
      "/home/codyt/supabase-docker/volumes/storage:/var/lib/storage:rw,z"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"imgproxy\", \"health\"]"
      "--health-interval=5s"
      "--health-retries=3"
      "--health-timeout=5s"
      "--network-alias=imgproxy"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-imgproxy" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-kong" = {
    image = "kong:2.8.1";
    environment = {
      "DASHBOARD_PASSWORD" = "this_password_is_insecure_and_should_be_updated";
      "DASHBOARD_USERNAME" = "supabase";
      "KONG_DATABASE" = "off";
      "KONG_DECLARATIVE_CONFIG" = "/home/kong/kong.yml";
      "KONG_DNS_ORDER" = "LAST,A,CNAME";
      "KONG_NGINX_PROXY_PROXY_BUFFERS" = "64 160k";
      "KONG_NGINX_PROXY_PROXY_BUFFER_SIZE" = "160k";
      "KONG_PLUGINS" = "request-transformer,cors,key-auth,acl,basic-auth";
      "SUPABASE_ANON_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE";
      "SUPABASE_SERVICE_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    volumes = [
      "/home/codyt/supabase-docker/volumes/api/kong.yml:/home/kong/temp.yml:ro,z"
    ];
    ports = [
      "8123:8000/tcp"
      "8443:8443/tcp"
    ];
    dependsOn = [
      "supabase-analytics"
    ];
    log-driver = "journald";
    extraOptions = [
      "--entrypoint=[\"bash\", \"-c\", \"eval \"echo \\\"$(cat ~/temp.yml)\\\"\" > ~/kong.yml && /docker-entrypoint.sh kong docker-start\"]"
      "--network-alias=kong"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-kong" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-meta" = {
    image = "supabase/postgres-meta:v0.89.3";
    environment = {
      "PG_META_DB_HOST" = "db";
      "PG_META_DB_NAME" = "postgres";
      "PG_META_DB_PASSWORD" = "your-super-secret-and-long-postgres-password";
      "PG_META_DB_PORT" = "5432";
      "PG_META_DB_USER" = "supabase_admin";
      "PG_META_PORT" = "8080";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    dependsOn = [
      "supabase-analytics"
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=meta"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-meta" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-pooler" = {
    image = "supabase/supavisor:2.5.1";
    environment = {
      "API_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "CLUSTER_POSTGRES" = "true";
      "DATABASE_URL" = "ecto://supabase_admin:your-super-secret-and-long-postgres-password@db:5432/_supabase";
      "ERL_AFLAGS" = "-proto_dist inet_tcp";
      "METRICS_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "POOLER_DEFAULT_POOL_SIZE" = "20";
      "POOLER_MAX_CLIENT_CONN" = "100";
      "POOLER_POOL_MODE" = "transaction";
      "POOLER_TENANT_ID" = "your-tenant-id";
      "PORT" = "4000";
      "POSTGRES_DB" = "postgres";
      "POSTGRES_PASSWORD" = "your-super-secret-and-long-postgres-password";
      "POSTGRES_PORT" = "5432";
      "REGION" = "local";
      "SECRET_KEY_BASE" = "UpNVntn3cDxHJpq99YMc1T1AQgQpc8kfYTuRgBiYa15BLrx8etQoXz3gZv1/u2oq";
      "VAULT_ENC_KEY" = "your-encryption-key-32-chars-min";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    volumes = [
      "/home/codyt/supabase-docker/volumes/pooler/pooler.exs:/etc/pooler/pooler.exs:ro,z"
    ];
    ports = [
      "5432:5432/tcp"
      "6543:6543/tcp"
    ];
    cmd = [ "/bin/sh" "-c" "/app/bin/migrate && /app/bin/supavisor eval \"$(cat /etc/pooler/pooler.exs)\" && /app/bin/server" ];
    dependsOn = [
      "supabase-analytics"
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"curl\", \"-sSfL\", \"--head\", \"-o\", \"/dev/null\", \"http://127.0.0.1:4000/api/health\"]"
      "--health-interval=10s"
      "--health-retries=5"
      "--health-timeout=5s"
      "--network-alias=supavisor"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-pooler" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-rest" = {
    image = "postgrest/postgrest:v12.2.12";
    environment = {
      "PGRST_APP_SETTINGS_JWT_EXP" = "3600";
      "PGRST_APP_SETTINGS_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "PGRST_DB_ANON_ROLE" = "anon";
      "PGRST_DB_SCHEMAS" = "public,storage,graphql_public";
      "PGRST_DB_URI" = "postgres://authenticator:your-super-secret-and-long-postgres-password@db:5432/postgres";
      "PGRST_DB_USE_LEGACY_GUCS" = "false";
      "PGRST_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    cmd = [ "postgrest" ];
    dependsOn = [
      "supabase-analytics"
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=rest"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-rest" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-storage" = {
    image = "supabase/storage-api:v1.23.0";
    environment = {
      "ANON_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE";
      "DATABASE_URL" = "postgres://supabase_storage_admin:your-super-secret-and-long-postgres-password@db:5432/postgres";
      "ENABLE_IMAGE_TRANSFORMATION" = "true";
      "FILE_SIZE_LIMIT" = "52428800";
      "FILE_STORAGE_BACKEND_PATH" = "/var/lib/storage";
      "GLOBAL_S3_BUCKET" = "stub";
      "IMGPROXY_URL" = "http://imgproxy:5001";
      "PGRST_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "POSTGREST_URL" = "http://rest:3000";
      "REGION" = "stub";
      "SERVICE_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q";
      "STORAGE_BACKEND" = "file";
      "TENANT_ID" = "stub";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    volumes = [
      "/home/codyt/supabase-docker/volumes/storage:/var/lib/storage:rw,z"
    ];
    dependsOn = [
      "supabase-db"
      "supabase-imgproxy"
      "supabase-rest"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"wget\", \"--no-verbose\", \"--tries=1\", \"--spider\", \"http://storage:5000/status\"]"
      "--health-interval=5s"
      "--health-retries=3"
      "--health-timeout=5s"
      "--network-alias=storage"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-storage" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-studio" = {
    image = "supabase/studio:2025.06.02-sha-8f2993d";
    environment = {
      "AUTH_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "DEFAULT_ORGANIZATION_NAME" = "Default Organization";
      "DEFAULT_PROJECT_NAME" = "Default Project";
      "LOGFLARE_PRIVATE_ACCESS_TOKEN" = "your-super-secret-and-long-logflare-key-private";
      "LOGFLARE_URL" = "http://analytics:4000";
      "NEXT_ANALYTICS_BACKEND_PROVIDER" = "postgres";
      "NEXT_PUBLIC_ENABLE_LOGS" = "true";
      "OPENAI_API_KEY" = "";
      "POSTGRES_PASSWORD" = "your-super-secret-and-long-postgres-password";
      "STUDIO_PG_META_URL" = "http://meta:8080";
      "SUPABASE_ANON_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE";
      "SUPABASE_PUBLIC_URL" = "http://localhost:8123";
      "SUPABASE_SERVICE_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q";
      "SUPABASE_URL" = "http://kong:8000";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    dependsOn = [
      "supabase-analytics"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"node\", \"-e\", \"fetch('http://studio:3000/api/platform/profile').then((r) => {if (r.status !== 200) throw new Error(r.status)})\"]"
      "--health-interval=5s"
      "--health-retries=3"
      "--health-timeout=10s"
      "--network-alias=studio"
      "--network=supabase_default"
    ];
  };
  systemd.services."docker-supabase-studio" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };
  virtualisation.oci-containers.containers."supabase-vector" = {
    image = "timberio/vector:0.28.1-alpine";
    environment = {
      "LOGFLARE_PUBLIC_ACCESS_TOKEN" = "your-super-secret-and-long-logflare-key-public";
    };
    environmentFiles = [
      "/home/codyt/supabase-docker/.env"
    ];
    volumes = [
      "/home/codyt/supabase-docker/volumes/logs/vector.yml:/etc/vector/vector.yml:ro,z"
      "/var/run/docker.sock:/var/run/docker.sock:ro,z"
    ];
    cmd = [ "--config" "/etc/vector/vector.yml" ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=[\"wget\", \"--no-verbose\", \"--tries=1\", \"--spider\", \"http://vector:9001/health\"]"
      "--health-interval=5s"
      "--health-retries=3"
      "--health-timeout=5s"
      "--network-alias=vector"
      "--network=supabase_default"
      "--security-opt=label=disable"
    ];
  };
  systemd.services."docker-supabase-vector" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-supabase_default.service"
    ];
    requires = [
      "docker-network-supabase_default.service"
    ];
    partOf = [
      "docker-compose-supabase-root.target"
    ];
    wantedBy = [
      "docker-compose-supabase-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-supabase_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f supabase_default";
    };
    script = ''
      docker network inspect supabase_default || docker network create supabase_default
    '';
    partOf = [ "docker-compose-supabase-root.target" ];
    wantedBy = [ "docker-compose-supabase-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-supabase_db-config" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect supabase_db-config || docker volume create supabase_db-config
    '';
    partOf = [ "docker-compose-supabase-root.target" ];
    wantedBy = [ "docker-compose-supabase-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-supabase-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
