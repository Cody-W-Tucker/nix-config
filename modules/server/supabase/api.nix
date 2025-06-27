{ config, lib, ... }:

{
  # Secrets
  sops.secrets = {
    SUPABASE_DASHBOARD_PASSWORD = { };
    SUPABASE_ANON_KEY = { }; # signed JWT
    SUPABASE_JWT_SECRET = { }; # shared JWT secret
    SUPABASE_POSTGRES_PASSWORD = { }; # db super-user password
    SUPABASE_SERVICE_ROLE_KEY = { }; # signed JWT
  };

  sops.templates = {
    "kong".content = ''
      DASHBOARD_PASSWORD=${config.sops.placeholder."SUPABASE_DASHBOARD_PASSWORD"}
      SUPABASE_ANON_KEY=${config.sops.placeholder."SUPABASE_ANON_KEY"}
      SUPABASE_SERVICE_KEY=${config.sops.placeholder."SUPABASE_SERVICE_ROLE_KEY"}
    '';
  };

  sops.templates = {
    "rest".content = ''
      PGRST_APP_SETTINGS_JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
      PGRST_DB_URI=postgres://authenticator:${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}@db:5432/postgres"
      PGRST_JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
    '';
  };

  virtualisation.oci-containers.containers."supabase-kong" = {
    image = "kong:2.8.1";
    environmentFiles = [
      config.sops.templates."kong".path
    ];
    environment = {
      # "DASHBOARD_PASSWORD" = "this_password_is_insecure_and_should_be_updated";
      "DASHBOARD_USERNAME" = "supabase";
      "KONG_DATABASE" = "off";
      "KONG_DECLARATIVE_CONFIG" = "/home/kong/kong.yml";
      "KONG_DNS_ORDER" = "LAST,A,CNAME";
      "KONG_NGINX_PROXY_PROXY_BUFFERS" = "64 160k";
      "KONG_NGINX_PROXY_PROXY_BUFFER_SIZE" = "160k";
      "KONG_PLUGINS" = "request-transformer,cors,key-auth,acl,basic-auth";
      # "SUPABASE_ANON_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE";
      # "SUPABASE_SERVICE_KEY" = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q";
    };
    volumes = [
      "/home/codyt/supabase-docker/volumes/api/kong.yml:/home/kong/temp.yml:ro,z"
    ];
    extraOptions = [
      "--entrypoint=bash"
      "--network=supabase_default"
      "--network-alias=kong"
    ];
    cmd = [
      "-c"
      ''eval "echo \"$(cat /home/kong/temp.yml)\"" > /home/kong/kong.yml \
        && exec /docker-entrypoint.sh kong docker-start''
    ];
    ports = [
      "8800:8000/tcp"
      "8443:8443/tcp"
    ];
    log-driver = "journald";
  };
  systemd.services."docker-supabase-kong" = {
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

  virtualisation.oci-containers.containers."supabase-rest" = {
    image = "postgrest/postgrest:v12.2.12";
    environmentFiles = [
      config.sops.templates."rest".path
    ];
    environment = {
      "PGRST_APP_SETTINGS_JWT_EXP" = "3600";
      # "PGRST_APP_SETTINGS_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
      "PGRST_DB_ANON_ROLE" = "anon";
      "PGRST_DB_SCHEMAS" = "public,storage,graphql_public";
      # "PGRST_DB_URI" = "postgres://authenticator:your-super-secret-and-long-postgres-password@db:5432/postgres";
      "PGRST_DB_USE_LEGACY_GUCS" = "false";
      # "PGRST_JWT_SECRET" = "your-super-secret-jwt-token-with-at-least-32-characters-long";
    };
    cmd = [ "postgrest" ];
    dependsOn = [
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
