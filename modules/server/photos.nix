{ config, pkgs, ... }:

{
  # Photoprism
  services.photoprism = {
    enable = true;
    port = 2342;
    originalsPath = "/var/lib/private/photoprism/originals";
    address = "127.0.0.1";
    settings = {
      PHOTOPRISM_ADMIN_USER = "admin";
      PHOTOPRISM_ADMIN_PASSWORD = "admin";
      PHOTOPRISM_DEFAULT_LOCALE = "en";
      PHOTOPRISM_DATABASE_DRIVER = "mysql";
      PHOTOPRISM_DATABASE_NAME = "photoprism";
      PHOTOPRISM_DATABASE_SERVER = "/run/mysqld/mysqld.sock";
      PHOTOPRISM_DATABASE_USER = "photoprism";
      PHOTOPRISM_SITE_URL = "https://photos.homehub.tv:2342";
      PHOTOPRISM_SITE_TITLE = "Photos";
    };
  };

  # MySQL
  services.mysql = {
    enable = true;
    dataDir = "/data/mysql";
    package = pkgs.mariadb;
    ensureDatabases = [ "photoprism" ];
    ensureUsers = [{
      name = "photoprism";
      ensurePermissions = {
        "photoprism.*" = "ALL PRIVILEGES";
      };
    }];
  };

  # NGINX
  services.nginx = {
    clientMaxBodySize = "500m";
    virtualHosts = {
      "photos.homehub.tv" = {
        forceSSL = true;
        useACMEHost = "homehub.tv";
        http2 = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:2342";
          proxyWebsockets = true;
        };
      };
    };
  };

  # Change the user and group for the systemd service
  systemd.services.photoprism.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "codyt";
    Group = lib.mkForce "users";
  };

  # Change the path to the originals directory
  fileSystems."/var/lib/private/photoprism/originals" =
    {
      device = "/mnt/hdd/Photos";
      options = [ "bind" ];
    };

  fileSystems."/var/lib/private/photoprism/import" =
    {
      device = "/var/lib/nextcloud/data/codyt/files/InstantUpload/Camera";
      options = [ "bind" ];
    };
}
