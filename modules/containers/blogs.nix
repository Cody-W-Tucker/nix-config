# Runs a local ghost blog in a container

{
  services.nginx.virtualHosts."mens-group.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/".proxyPass = "http://localhost:2368";
  };

  virtualisation.oci-containers.containers = {
    "ghost-mens-group" = {
      # Keep up-to-date
      # Instructions at https://hub.docker.com/_/ghost
      # Must upgrade to latest minor version before upgrading major version
      # or database issues will occur
      image = "ghost:5.89.5";
      autoStart = true;
      ports = [ "2368:2368" ];
      environment = {
        url = "https://mens-group.homehub.tv";
        NODE_ENV = "development";

        database__client = "mysql";
        database__connection__host = "db-mens-group";
        database__connection__user = "root";
        database__connection__password = "example";
        database__connection__database = "ghost";
      };

      dependsOn = [ "db-mens-group" ];
      volumes = [ "/var/lib/ghost/content:/var/lib/ghost/content" ];
    };

    "db-mens-group" = {
      image = "mysql:lts";
      autoStart = true;
      environment = {
        MYSQL_ROOT_PASSWORD = "example";
        MYSQL_DATABASE = "ghost";
      };
    };
  };
}
