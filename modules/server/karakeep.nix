# Auto-generated using compose2nix v0.3.2-pre.
{ config, pkgs, lib, ... }:

{
  services.nginx.virtualHosts = {
    "karakeep.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/".proxyPass = "http://localhost:2468";
      kTLS = true;
    };
  };

  # Containers
  virtualisation.oci-containers.containers."karakeep-chrome" = {
    image = "gcr.io/zenika-hub/alpine-chrome:124";
    cmd = [ "--no-sandbox" "--disable-gpu" "--disable-dev-shm-usage" "--remote-debugging-address=0.0.0.0" "--remote-debugging-port=9222" "--hide-scrollbars" ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=chrome"
      "--network=karakeep_default"
      "--pull=always"
    ];
  };
  systemd.services."docker-karakeep-chrome" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
    ];
    partOf = [
      "docker-compose-karakeep-root.target"
    ];
    wantedBy = [
      "docker-compose-karakeep-root.target"
    ];
  };

  # Get the creds
  sops.secrets = {
    OPENAI_API_KEY = { };
    MEILI_MASTER_KEY = { };
    NEXTAUTH_SECRET = { };
  };

  sops.templates = {
    "MEILI_and_NEXTAUTH".content = ''
      MEILI_MASTER_KEY=${config.sops.placeholder."MEILI_MASTER_KEY"}
      NEXTAUTH_SECRET=${config.sops.placeholder."NEXTAUTH_SECRET"}
    '';
    "OPENAI_API".content = ''
      OPENAI_API_KEY=${config.sops.placeholder."OPENAI_API_KEY"}
    '';
  };

  virtualisation.oci-containers.containers."karakeep-meilisearch" = {
    image = "getmeili/meilisearch:v1.13.3";
    environmentFiles = [
      config.sops.templates."MEILI_and_NEXTAUTH".path
    ];
    environment = {
      "KARAKEEP_VERSION" = "release";
      "NEXTAUTH_URL" = "http://localhost:3000";
      "MEILI_NO_ANALYTICS" = "true";
    };
    volumes = [
      "karakeep_meilisearch:/meili_data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=meilisearch"
      "--network=karakeep_default"
      "--pull=always"
    ];
  };
  systemd.services."docker-karakeep-meilisearch" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
      "docker-volume-karakeep_meilisearch.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
      "docker-volume-karakeep_meilisearch.service"
    ];
    partOf = [
      "docker-compose-karakeep-root.target"
    ];
    wantedBy = [
      "docker-compose-karakeep-root.target"
    ];
  };
  virtualisation.oci-containers.containers."karakeep-web" = {
    image = "ghcr.io/karakeep-app/karakeep:release";
    environmentFiles = [
      config.sops.templates."MEILI_and_NEXTAUTH".path
      config.sops.templates."OPENAI_API".path
    ];
    environment = {
      "BROWSER_WEB_URL" = "http://chrome:9222";
      "DATA_DIR" = "/data";
      "KARAKEEP_VERSION" = "release";
      "MEILI_ADDR" = "http://meilisearch:7700";
      "NEXTAUTH_URL" = "http://localhost:3000";
    };
    volumes = [
      "karakeep_data:/data:rw"
    ];
    ports = [
      "2468:3000/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=web"
      "--network=karakeep_default"
      "--pull=always"
    ];
  };
  systemd.services."docker-karakeep-web" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-karakeep_default.service"
      "docker-volume-karakeep_data.service"
    ];
    requires = [
      "docker-network-karakeep_default.service"
      "docker-volume-karakeep_data.service"
    ];
    partOf = [
      "docker-compose-karakeep-root.target"
    ];
    wantedBy = [
      "docker-compose-karakeep-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-karakeep_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f karakeep_default";
    };
    script = ''
      docker network inspect karakeep_default || docker network create karakeep_default
    '';
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-karakeep_data" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect karakeep_data || docker volume create karakeep_data
    '';
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };
  systemd.services."docker-volume-karakeep_meilisearch" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect karakeep_meilisearch || docker volume create karakeep_meilisearch
    '';
    partOf = [ "docker-compose-karakeep-root.target" ];
    wantedBy = [ "docker-compose-karakeep-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-karakeep-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
