{ config, lib, ... }:

{
  # Secrets
  sops.secrets = {
    SUPABASE_ANON_KEY = { };
    SUPABASE_JWT_SECRET = { };
    SUPABASE_POSTGRES_PASSWORD = { };
    SUPABASE_SERVICE_ROLE_KEY = { };
  };

  sops.templates = {
    "storage".content = ''
      ANON_KEY=${config.sops.placeholder."SUPABASE_ANON_KEY"}
      DATABASE_URL=postgres://supabase_storage_admin:${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}@db:5432/postgres
      PGRST_JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
      SERVICE_KEY=${config.sops.placeholder."SUPABASE_SERVICE_ROLE_KEY"}
    '';
  };

  virtualisation.oci-containers.containers."supabase-storage" = {
    image = "supabase/storage-api:v1.23.0";
    environmentFiles = [
      config.sops.templates."storage".path
    ];
    environment = {
      "ENABLE_IMAGE_TRANSFORMATION" = "true";
      "FILE_SIZE_LIMIT" = "52428800";
      "FILE_STORAGE_BACKEND_PATH" = "/var/lib/storage";
      "GLOBAL_S3_BUCKET" = "stub";
      "IMGPROXY_URL" = "http://imgproxy:5001";
      "POSTGREST_URL" = "http://rest:3000";
      "REGION" = "stub";
      "STORAGE_BACKEND" = "file";
      "TENANT_ID" = "stub";
    };
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
      "--health-cmd=wget --no-verbose --tries=1 --spider http://storage:5000/status"
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

  virtualisation.oci-containers.containers."supabase-imgproxy" = {
    image = "darthsim/imgproxy:v3.8.0";
    environment = {
      "IMGPROXY_BIND" = ":5001";
      "IMGPROXY_ENABLE_WEBP_DETECTION" = "true";
      "IMGPROXY_LOCAL_FILESYSTEM_ROOT" = "/";
      "IMGPROXY_USE_ETAG" = "true";
    };
    volumes = [
      "/home/codyt/supabase-docker/volumes/storage:/var/lib/storage:rw,z"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=imgproxy health"
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
}
