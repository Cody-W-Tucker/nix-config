{ config, lib, ... }:
{

  # Secrets
  sops.secrets = {
    SUPABASE_JWT_SECRET = { }; # shared JWT secret
    SUPABASE_ANON_KEY = { };
    SUPABASE_POSTGRES_PASSWORD = { }; # db super-user password
    SUPABASE_SERVICE_ROLE_KEY = { };
  };

  sops.templates = {
    "edge-functions".content = ''
      JWT_SECRET=${config.sops.placeholder."SUPABASE_JWT_SECRET"}
      SUPABASE_ANON_KEY=${config.sops.placeholder."SUPABASE_ANON_KEY"}
      SUPABASE_DB_URL=postgres://postgres:${config.sops.placeholder."SUPABASE_POSTGRES_PASSWORD"}@db:5432/postgres"
      SUPABASE_SERVICE_ROLE_KEY=${config.sops.placeholder."SUPABASE_SERVICE_ROLE_KEY"}
    '';
  };

  virtualisation.oci-containers.containers."supabase-edge-functions" = {
    image = "supabase/edge-runtime:v1.67.4";
    environmentFiles = [
      config.sops.templates."edge-functions".path
    ];
    environment = {
      "SUPABASE_URL" = "http://kong:8000";
      "VERIFY_JWT" = "false";
    };
    volumes = [
      "/home/codyt/supabase-docker/volumes/functions:/home/deno/functions:rw,Z"
    ];
    cmd = [ "start" ];
    dependsOn = [
      "supabase-db"
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
