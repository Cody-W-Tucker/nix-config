{ config, lib, pkgs, ... }:

{
  environment.etc."nextcloud-admin-pass".text = "admin";

  virtualisation = {
    docker.enable = true;
    oci-containers.backend = "docker";
    # Online document editing
    oci-containers.containers."collabora" = {
      autoStart = true;
      image = "docker.io/collabora/code:latest";
      ports = [ "9980:9980/tcp" ];
      environment = {
        domain = "docs.homehub.tv";
        server_name = "docs.homehub.tv";
        dictionaries = "en_US";
        extra_params = "--o:ssl.enable=false --o:ssl.termination=true";
      };
      extraOptions = [ "--cap-add" "MKNOD" ];
    };
  };

  services = {
    nginx.virtualHosts = {
      "homehub.tv" = {
        forceSSL = false;
        enableACME = false;
      };
      "docs.homehub.tv" = {
        enableACME = true;
        forceSSL = true;
        extraConfig = ''
           # static files
           location ^~ /browser {
             proxy_pass http://127.0.0.1:9980;
             proxy_set_header Host $host;
           }

           # WOPI discovery URL
           location ^~ /hosting/discovery {
             proxy_pass http://127.0.0.1:9980;
             proxy_set_header Host $host;
           }

           # Capabilities
           location ^~ /hosting/capabilities {
             proxy_pass http://127.0.0.1:9980;
             proxy_set_header Host $host;
          }

          # main websocket
          location ~ ^/cool/(.*)/ws$ {
            proxy_pass http://127.0.0.1:9980;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 36000s;
          }

          # download, presentation and image upload
          location ~ ^/(c|l)ool {
            proxy_pass http://127.0.0.1:9980;
            proxy_set_header Host $host;
          }

          # Admin Console websocket
          location ^~ /cool/adminws {
            proxy_pass http://127.0.0.1:9980;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Host $host;
            proxy_read_timeout 36000s;
          }
        '';
      };
    };
    nextcloud = {
      enable = true;
      hostName = "homehub.tv";
      package = pkgs.nextcloud29;
      database.createLocally = true;
      configureRedis = true;
      # Increase the maximum file upload size to avoid problems uploading videos.
      maxUploadSize = "4G";
      https = false;
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # List of apps we want to install and are already packaged in
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
        inherit calendar contacts mail notes richdocuments tasks cookbook;
      };

      config = {
        dbtype = "mysql";
        adminuser = "admin";
        adminpassFile = "/etc/nextcloud-admin-pass";
      };
      settings = {
        overwriteprotocol = "http";
        trusted_proxies = [ "127.0.0.1" ];
        trusted_domains = [ "homehub.tv" "docs.homehub.tv" ];
      };
    };
  };
}
