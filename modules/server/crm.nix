# Auto-generated using compose2nix v0.3.1.
{ pkgs, lib, ... }:

{
  # Runtime
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
  virtualisation.oci-containers.backend = "docker";

  # Containers
  virtualisation.oci-containers.containers."twenty-db" = {
    image = "postgres:16";
    environment = {
      "POSTGRES_PASSWORD" = "secret";
      "POSTGRES_USER" = "postgres";
    };
    volumes = [
      "twenty_db-data:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -U postgres -h localhost -d postgres"
      "--health-interval=5s"
      "--health-retries=10"
      "--health-timeout=5s"
      "--network-alias=db"
      "--network=twenty_default"
    ];
  };
  systemd.services."docker-twenty-db" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-twenty_default.service"
      "docker-volume-twenty_db-data.service"
    ];
    requires = [
      "docker-network-twenty_default.service"
      "docker-volume-twenty_db-data.service"
    ];
    partOf = [
      "docker-compose-twenty-root.target"
    ];
    wantedBy = [
      "docker-compose-twenty-root.target"
    ];
  };
  virtualisation.oci-containers.containers."twenty-redis" = {
    image = "redis";
    cmd = [ "--maxmemory-policy" "noeviction" ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=redis"
      "--network=twenty_default"
    ];
  };
  systemd.services."docker-twenty-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-twenty_default.service"
    ];
    requires = [
      "docker-network-twenty_default.service"
    ];
    partOf = [
      "docker-compose-twenty-root.target"
    ];
    wantedBy = [
      "docker-compose-twenty-root.target"
    ];
  };
  virtualisation.oci-containers.containers."twenty-server" = {
    image = "twentycrm/twenty:latest";
    environment = {
      "APP_SECRET" = "";
      "DISABLE_CRON_JOBS_REGISTRATION" = "";
      "DISABLE_DB_MIGRATIONS" = "";
      "NODE_PORT" = "3000";
      "PG_DATABASE_URL" = "postgres://postgres:secret@db:5432/default";
      "REDIS_URL" = "redis://redis:6379";
      "SERVER_URL" = "http://localhost:3000";
      "STORAGE_S3_ENDPOINT" = "";
      "STORAGE_S3_NAME" = "";
      "STORAGE_S3_REGION" = "";
      "STORAGE_TYPE" = "local";
    };
    volumes = [
      "twenty_server-local-data:/app/packages/twenty-server/.local-storage:rw"
    ];
    ports = [
      "3000:3000/tcp"
    ];
    dependsOn = [
      "twenty-db"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=curl --fail http://localhost:3000/healthz"
      "--health-interval=5s"
      "--health-retries=20"
      "--health-timeout=5s"
      "--network-alias=server"
      "--network=twenty_default"
    ];
  };
  systemd.services."docker-twenty-server" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-twenty_default.service"
      "docker-volume-twenty_server-local-data.service"
    ];
    requires = [
      "docker-network-twenty_default.service"
      "docker-volume-twenty_server-local-data.service"
    ];
    partOf = [
      "docker-compose-twenty-root.target"
    ];
    wantedBy = [
      "docker-compose-twenty-root.target"
    ];
  };
  virtualisation.oci-containers.containers."twenty-worker" = {
    image = "twentycrm/twenty:latest";
    environment = {
      "APP_SECRET" = "Y7mST0L4WB2E0fINLPk0e3rC7/GNdKx6O2mj24BpSTo=";
      "DISABLE_CRON_JOBS_REGISTRATION" = "true";
      "DISABLE_DB_MIGRATIONS" = "true";
      "PG_DATABASE_URL" = "postgres://postgres:secret@db:5432/default";
      "REDIS_URL" = "redis://redis:6379";
      "SERVER_URL" = "http://localhost:3000";
      "STORAGE_S3_ENDPOINT" = "";
      "STORAGE_S3_NAME" = "";
      "STORAGE_S3_REGION" = "";
      "STORAGE_TYPE" = "local";
    };
    volumes = [
      "twenty_server-local-data:/app/packages/twenty-server/.local-storage:rw"
    ];
    cmd = [ "yarn" "worker:prod" ];
    dependsOn = [
      "twenty-db"
      "twenty-server"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=worker"
      "--network=twenty_default"
    ];
  };
  systemd.services."docker-twenty-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-twenty_default.service"
      "docker-volume-twenty_server-local-data.service"
    ];
    requires = [
      "docker-network-twenty_default.service"
      "docker-volume-twenty_server-local-data.service"
    ];
    partOf = [
      "docker-compose-twenty-root.target"
    ];
    wantedBy = [
      "docker-compose-twenty-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-twenty_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f twenty_default";
    };
    script = ''
      docker network inspect twenty_default || docker network create twenty_default
    '';
    partOf = [ "docker-compose-twenty-root.target" ];
    wantedBy = [ "docker-compose-twenty-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-twenty_db-data" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect twenty_db-data || docker volume create twenty_db-data
    '';
    partOf = [ "docker-compose-twenty-root.target" ];
    wantedBy = [ "docker-compose-twenty-root.target" ];
  };
  systemd.services."docker-volume-twenty_server-local-data" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect twenty_server-local-data || docker volume create twenty_server-local-data
    '';
    partOf = [ "docker-compose-twenty-root.target" ];
    wantedBy = [ "docker-compose-twenty-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-twenty-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
