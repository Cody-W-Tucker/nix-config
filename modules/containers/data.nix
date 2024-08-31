{
  virtualisation.oci-containers.containers = {
    nocodb = {
      image = "nocodb/nocodb:latest";
      ports = [ "7070:8080" ];
      environment = {
        NC_DB = "pg://root_db:5432?u=postgres&p=password&d=root_db";
      };
      volumes = [
        {
          source = "/path/to/local/nc_data";
          target = "/usr/app/data";
        }
      ];
      extraOptions = [
        "--link=root_db:root_db"
      ];
      restartPolicy = "always";
    };

    root_db = {
      image = "postgres";
      environment = {
        POSTGRES_DB = "root_db";
        POSTGRES_PASSWORD = "password";
        POSTGRES_USER = "postgres";
      };
      healthcheck = {
        test = "pg_isready -U \"$$POSTGRES_USER\" -d \"$$POSTGRES_DB\"";
        interval = "10s";
        timeout = "2s";
        retries = 10;
      };
      volumes = [
        {
          source = "/path/to/local/db_data";
          target = "/var/lib/postgresql/data";
        }
      ];
      restartPolicy = "always";
    };
  };
}
