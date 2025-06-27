{ config, lib, pkgs, ... }:

{
  # Secrets
  sops.secrets = {
    SUPABASE_JWT_SECRET = { };
    SUPABASE_POSTGRES_PASSWORD = { };
    SUPABASE_SECRET_KEY_BASE = { };
    SUPABASE_VAULT_ENC_KEY = { };
  };

  sops.templates = {
    "db".content = ''
      PGPASSWORD=${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}
      POSTGRES_PASSWORD=${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}
      JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
    '';
  };

  sops.templates = {
    "auth".content = ''
      GOTRUE_DB_DATABASE_URL=postgres://supabase_auth_admin:${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}@db:5432/postgres
      GOTRUE_JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
    '';
  };

  sops.templates = {
    "meta".content = ''
      PG_META_DB_PASSWORD=${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}
    '';
  };

  sops.templates = {
    "pooler".content = ''
      API_JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
      DATABASE_URL=postgres://supabase_admin:${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}@db:5432/postgres
      METRICS_JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
      POSTGRES_PASSWORD=${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}
      SECRET_KEY_BASE=${config.sops.placeholder."SUPABASE_SECRET_KEY_BASE"}
      VAULT_ENC_KEY=${config.sops.placeholder."SUPABASE_VAULT_ENC_KEY"}
    '';
  };

  virtualisation.oci-containers.containers."supabase-db" = {
    image = "supabase/postgres:15.8.1.060";
    environmentFiles = [
      config.sops.templates."db".path
    ];
    environment = {
      "JWT_EXP" = "3600";
      "PGDATABASE" = "postgres";
      "PGPORT" = "5432";
      "POSTGRES_DB" = "postgres";
      "POSTGRES_HOST" = "/var/run/postgresql";
      "POSTGRES_PORT" = "5432";
    };
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
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -U postgres -h localhost"
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
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
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

  virtualisation.oci-containers.containers."supabase-auth" = {
    image = "supabase/gotrue:v2.174.0";
    environmentFiles = [
      config.sops.templates."auth".path
    ];
    environment = {
      "API_EXTERNAL_URL" = "http://localhost:8800";
      "GOTRUE_API_HOST" = "0.0.0.0";
      "GOTRUE_API_PORT" = "9999";
      "GOTRUE_DB_DRIVER" = "postgres";
      "GOTRUE_DISABLE_SIGNUP" = "false";
      "GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED" = "false";
      "GOTRUE_EXTERNAL_EMAIL_ENABLED" = "true";
      "GOTRUE_EXTERNAL_PHONE_ENABLED" = "true";
      "GOTRUE_JWT_ADMIN_ROLES" = "service_role";
      "GOTRUE_JWT_AUD" = "authenticated";
      "GOTRUE_JWT_DEFAULT_GROUP_NAME" = "authenticated";
      "GOTRUE_JWT_EXP" = "3600";
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
    dependsOn = [
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=wget --no-verbose --tries=1 --spider http://localhost:9999/health"
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
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
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
    environmentFiles = [
      config.sops.templates."meta".path
    ];
    environment = {
      "PG_META_DB_HOST" = "db";
      "PG_META_DB_NAME" = "postgres";
      "PG_META_DB_PORT" = "5432";
      "PG_META_DB_USER" = "supabase_admin";
      "PG_META_PORT" = "8080";
    };
    dependsOn = [
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
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
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
    environmentFiles = [
      config.sops.templates."pooler".path
    ];
    environment = {
      "CLUSTER_POSTGRES" = "true";
      "ERL_AFLAGS" = "-proto_dist inet_tcp";
      "POOLER_DEFAULT_POOL_SIZE" = "20";
      "POOLER_MAX_CLIENT_CONN" = "100";
      "POOLER_POOL_MODE" = "transaction";
      "POOLER_TENANT_ID" = "your-tenant-id";
      "PORT" = "4000";
      "POSTGRES_DB" = "postgres";
      "POSTGRES_PORT" = "5432";
      "REGION" = "local";
    };
    volumes = [
      "/home/codyt/supabase-docker/volumes/pooler/pooler.exs:/etc/pooler/pooler.exs:ro,z"
    ];
    ports = [
      "15432:5432/tcp"
      "6543:6543/tcp"
    ];
    cmd = [ "/bin/sh" "-c" "/app/bin/migrate && /app/bin/supavisor eval \"$(cat /etc/pooler/pooler.exs)\" && /app/bin/server" ];
    dependsOn = [
      "supabase-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=curl -sSfL --head -o /dev/null http://127.0.0.1:4000/api/health"
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
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
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
}
