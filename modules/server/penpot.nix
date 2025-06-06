# Auto-generated using compose2nix v0.3.2-pre.
{ pkgs, lib, config, ... }:

{
  # Proxy
  services.nginx.virtualHosts = {
    "design.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://localhost:8888";
      };
    };
  };

  # Enable container name DNS for all docker networks.
  networking.firewall.interfaces =
    let
      matchAll = if !config.networking.nftables.enable then "docker+" else "docker*";
    in
    {
      "${matchAll}".allowedUDPPorts = [ 53 ];
    };

  # Containers
  virtualisation.oci-containers.containers."penpot-penpot-backend" = {
    image = "penpotapp/backend:latest";
    environment = {
      "PENPOT_ASSETS_STORAGE_BACKEND" = "assets-fs";
      "PENPOT_DATABASE_PASSWORD" = "penpot";
      "PENPOT_DATABASE_URI" = "postgresql://penpot-postgres/penpot";
      "PENPOT_DATABASE_USERNAME" = "penpot";
      "PENPOT_FLAGS" = "disable-email-verification enable-smtp enable-prepl-server disable-secure-session-cookies";
      "PENPOT_HTTP_SERVER_MAX_BODY_SIZE" = "31457280";
      "PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE" = "367001600";
      "PENPOT_PUBLIC_URI" = "http://localhost:8888";
      "PENPOT_REDIS_URI" = "redis://penpot-redis/0";
      "PENPOT_SMTP_DEFAULT_FROM" = "no-reply@example.com";
      "PENPOT_SMTP_DEFAULT_REPLY_TO" = "no-reply@example.com";
      "PENPOT_SMTP_HOST" = "penpot-mailcatch";
      "PENPOT_SMTP_PORT" = "1025";
      "PENPOT_SMTP_SSL" = "false";
      "PENPOT_SMTP_TLS" = "false";
      "PENPOT_STORAGE_ASSETS_FS_DIRECTORY" = "/opt/data/assets";
      "PENPOT_TELEMETRY_ENABLED" = "true";
      "PENPOT_TELEMETRY_REFERER" = "compose";
    };
    volumes = [
      "penpot_penpot_assets:/opt/data/assets:rw"
    ];
    dependsOn = [
      "penpot-penpot-postgres"
      "penpot-penpot-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=penpot-backend"
      "--network=penpot_penpot"
    ];
  };
  systemd.services."docker-penpot-penpot-backend" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-penpot_penpot.service"
      "docker-volume-penpot_penpot_assets.service"
    ];
    requires = [
      "docker-network-penpot_penpot.service"
      "docker-volume-penpot_penpot_assets.service"
    ];
    partOf = [
      "docker-compose-penpot-root.target"
    ];
    wantedBy = [
      "docker-compose-penpot-root.target"
    ];
  };
  virtualisation.oci-containers.containers."penpot-penpot-exporter" = {
    image = "penpotapp/exporter:latest";
    environment = {
      "PENPOT_PUBLIC_URI" = "http://penpot-frontend:8888";
      "PENPOT_REDIS_URI" = "redis://penpot-redis/0";
    };
    dependsOn = [
      "penpot-penpot-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=penpot-exporter"
      "--network=penpot_penpot"
    ];
  };
  systemd.services."docker-penpot-penpot-exporter" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-penpot_penpot.service"
    ];
    requires = [
      "docker-network-penpot_penpot.service"
    ];
    partOf = [
      "docker-compose-penpot-root.target"
    ];
    wantedBy = [
      "docker-compose-penpot-root.target"
    ];
  };
  virtualisation.oci-containers.containers."penpot-penpot-frontend" = {
    image = "penpotapp/frontend:latest";
    environment = {
      "PENPOT_FLAGS" = "disable-email-verification enable-smtp enable-prepl-server disable-secure-session-cookies";
      "PENPOT_HTTP_SERVER_MAX_BODY_SIZE" = "31457280";
      "PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE" = "367001600";
    };
    volumes = [
      "penpot_penpot_assets:/opt/data/assets:rw"
    ];
    ports = [
      "8888:8080/tcp"
    ];
    dependsOn = [
      "penpot-penpot-backend"
      "penpot-penpot-exporter"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=penpot-frontend"
      "--network=penpot_penpot"
    ];
  };
  systemd.services."docker-penpot-penpot-frontend" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-penpot_penpot.service"
      "docker-volume-penpot_penpot_assets.service"
    ];
    requires = [
      "docker-network-penpot_penpot.service"
      "docker-volume-penpot_penpot_assets.service"
    ];
    partOf = [
      "docker-compose-penpot-root.target"
    ];
    wantedBy = [
      "docker-compose-penpot-root.target"
    ];
  };
  virtualisation.oci-containers.containers."penpot-penpot-mailcatch" = {
    image = "sj26/mailcatcher:latest";
    ports = [
      "1080:1080/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=penpot-mailcatch"
      "--network=penpot_penpot"
    ];
  };
  systemd.services."docker-penpot-penpot-mailcatch" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-penpot_penpot.service"
    ];
    requires = [
      "docker-network-penpot_penpot.service"
    ];
    partOf = [
      "docker-compose-penpot-root.target"
    ];
    wantedBy = [
      "docker-compose-penpot-root.target"
    ];
  };
  virtualisation.oci-containers.containers."penpot-penpot-postgres" = {
    image = "postgres:15";
    environment = {
      "POSTGRES_DB" = "penpot";
      "POSTGRES_INITDB_ARGS" = "--data-checksums";
      "POSTGRES_PASSWORD" = "penpot";
      "POSTGRES_USER" = "penpot";
    };
    volumes = [
      "penpot_penpot_postgres_v15:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=pg_isready -U penpot"
      "--health-interval=2s"
      "--health-retries=5"
      "--health-start-period=2s"
      "--health-timeout=10s"
      "--network-alias=penpot-postgres"
      "--network=penpot_penpot"
    ];
  };
  systemd.services."docker-penpot-penpot-postgres" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-penpot_penpot.service"
      "docker-volume-penpot_penpot_postgres_v15.service"
    ];
    requires = [
      "docker-network-penpot_penpot.service"
      "docker-volume-penpot_penpot_postgres_v15.service"
    ];
    partOf = [
      "docker-compose-penpot-root.target"
    ];
    wantedBy = [
      "docker-compose-penpot-root.target"
    ];
  };
  virtualisation.oci-containers.containers."penpot-penpot-redis" = {
    image = "redis:7.2";
    log-driver = "journald";
    extraOptions = [
      "--health-cmd=redis-cli ping | grep PONG"
      "--health-interval=1s"
      "--health-retries=5"
      "--health-start-period=3s"
      "--health-timeout=3s"
      "--network-alias=penpot-redis"
      "--network=penpot_penpot"
    ];
  };
  systemd.services."docker-penpot-penpot-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "docker-network-penpot_penpot.service"
    ];
    requires = [
      "docker-network-penpot_penpot.service"
    ];
    partOf = [
      "docker-compose-penpot-root.target"
    ];
    wantedBy = [
      "docker-compose-penpot-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-penpot_penpot" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f penpot_penpot";
    };
    script = ''
      docker network inspect penpot_penpot || docker network create penpot_penpot
    '';
    partOf = [ "docker-compose-penpot-root.target" ];
    wantedBy = [ "docker-compose-penpot-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-penpot_penpot_assets" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect penpot_penpot_assets || docker volume create penpot_penpot_assets
    '';
    partOf = [ "docker-compose-penpot-root.target" ];
    wantedBy = [ "docker-compose-penpot-root.target" ];
  };
  systemd.services."docker-volume-penpot_penpot_postgres_v15" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect penpot_penpot_postgres_v15 || docker volume create penpot_penpot_postgres_v15
    '';
    partOf = [ "docker-compose-penpot-root.target" ];
    wantedBy = [ "docker-compose-penpot-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-penpot-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
