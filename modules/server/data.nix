{ config, ... }:

{
  # Nginx reverse proxy for nocodb
  services.nginx.virtualHosts = {
    "data.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/".proxyPass = "http://localhost:7070";
      kTLS = true;
    };
  };
  virtualisation.oci-containers.containers = {
    "nocodb" = {
      autoStart = true;
      image = "nocodb/nocodb:latest";
      ports = [ "7070:8080" ];
      environment = {
        NC_DB = "pg://root_db:5432?u=postgres&p=password&d=root_db";
        NC_DISABLE_TELE = "true";
        NC_PUBLIC_URL = "https://data.homehub.tv";
      };
      volumes = [
        "${config.users.users.codyt.home}/data/nc_data:/usr/app/data"
      ];
      extraOptions = [
        "--link=root_db:root_db"
        "--link=data_db:data_db"
      ];
    };
    # Postgres backend for nocodb
    "root_db" = {
      autoStart = true;
      image = "postgres";
      environment = {
        POSTGRES_DB = "root_db";
        POSTGRES_PASSWORD = "password";
        POSTGRES_USER = "postgres";
      };
      extraOptions = [
        "--health-cmd=pg_isready -U postgres -d root_db"
        "--health-interval=10s"
        "--health-timeout=2s"
        "--health-retries=10"
      ];
      volumes = [
        "${config.users.users.codyt.home}/data/pg_data:/var/lib/postgresql/data"
      ];
    };
    # Separate database for data
    "data_db" = {
      autoStart = true;
      image = "postgres";
      environment = {
        POSTGRES_DB = "data_db";
        POSTGRES_PASSWORD = "password";
        POSTGRES_USER = "postgres";
      };
      extraOptions = [
        "--health-cmd=pg_isready -U postgres -d data_db"
        "--health-interval=10s"
        "--health-timeout=2s"
        "--health-retries=10"
      ];
      volumes = [
        "${config.users.users.codyt.home}/data/data_pg_data:/var/lib/postgresql/data"
      ];
    };
  };
}
