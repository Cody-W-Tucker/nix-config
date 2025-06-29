# Auto-generated using compose2nix v0.3.2-pre.
{ config, pkgs, lib, ... }:

{
  services.nginx.virtualHosts = {
    "hoarder.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/".proxyPass = "http://localhost:2468";
      kTLS = true;
    };
  };

  # Containers
  virtualisation.oci-containers.containers."hoarder-chrome" = {
    image = "gcr.io/zenika-hub/alpine-chrome:123";
    cmd = [ "--no-sandbox" "--disable-gpu" "--disable-dev-shm-usage" "--remote-debugging-address=0.0.0.0" "--remote-debugging-port=9222" "--hide-scrollbars" ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=chrome"
      "--network=hoarder_default"
      "--pull=always"
    ];
  };
  systemd.services."docker-hoarder-chrome" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-hoarder_default.service"
    ];
    requires = [
      "docker-network-hoarder_default.service"
    ];
    partOf = [
      "docker-compose-hoarder-root.target"
    ];
    wantedBy = [
      "docker-compose-hoarder-root.target"
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

  virtualisation.oci-containers.containers."hoarder-meilisearch" = {
    image = "getmeili/meilisearch:v1.11.1";
    environmentFiles = [
      config.sops.templates."MEILI_and_NEXTAUTH".path
    ];
    environment = {
      "HOARDER_VERSION" = "release";
      "NEXTAUTH_URL" = "http://localhost:3000";
      "MEILI_NO_ANALYTICS" = "true";
    };
    volumes = [
      "hoarder_meilisearch:/meili_data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=meilisearch"
      "--network=hoarder_default"
      "--pull=always"
    ];
  };
  systemd.services."docker-hoarder-meilisearch" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-hoarder_default.service"
      "docker-volume-hoarder_meilisearch.service"
    ];
    requires = [
      "docker-network-hoarder_default.service"
      "docker-volume-hoarder_meilisearch.service"
    ];
    partOf = [
      "docker-compose-hoarder-root.target"
    ];
    wantedBy = [
      "docker-compose-hoarder-root.target"
    ];
  };
  virtualisation.oci-containers.containers."hoarder-web" = {
    image = "ghcr.io/hoarder-app/hoarder:release";
    environmentFiles = [
      config.sops.templates."MEILI_and_NEXTAUTH".path
      config.sops.templates."OPENAI_API".path
    ];
    environment = {
      "BROWSER_WEB_URL" = "http://chrome:9222";
      "DATA_DIR" = "/data";
      "HOARDER_VERSION" = "release";
      "MEILI_ADDR" = "http://meilisearch:7700";
      "NEXTAUTH_URL" = "http://localhost:3000";
    };
    volumes = [
      "hoarder_data:/data:rw"
    ];
    ports = [
      "2468:3000/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=web"
      "--network=hoarder_default"
      "--pull=always"
    ];
  };
  systemd.services."docker-hoarder-web" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-hoarder_default.service"
      "docker-volume-hoarder_data.service"
    ];
    requires = [
      "docker-network-hoarder_default.service"
      "docker-volume-hoarder_data.service"
    ];
    partOf = [
      "docker-compose-hoarder-root.target"
    ];
    wantedBy = [
      "docker-compose-hoarder-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-hoarder_default" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f hoarder_default";
    };
    script = ''
      docker network inspect hoarder_default || docker network create hoarder_default
    '';
    partOf = [ "docker-compose-hoarder-root.target" ];
    wantedBy = [ "docker-compose-hoarder-root.target" ];
  };

  # Volumes
  systemd.services."docker-volume-hoarder_data" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect hoarder_data || docker volume create hoarder_data
    '';
    partOf = [ "docker-compose-hoarder-root.target" ];
    wantedBy = [ "docker-compose-hoarder-root.target" ];
  };
  systemd.services."docker-volume-hoarder_meilisearch" = {
    path = [ pkgs.docker ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect hoarder_meilisearch || docker volume create hoarder_meilisearch
    '';
    partOf = [ "docker-compose-hoarder-root.target" ];
    wantedBy = [ "docker-compose-hoarder-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-hoarder-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
