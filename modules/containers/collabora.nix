{ config, ... }:

{
  # Online document editing
  virtualisation.oci-containers.containers."collabora" = {
    autoStart = true;
    image = "docker.io/collabora/code:latest";
    ports = [ "9980:9980/tcp" ];
    environment = {
      server_name = "docs.homehub.tv";
      dictionaries = "en_US";
      extra_params = "--o:ssl.enable=false --o:ssl.termination=true";
    };
    extraOptions = [ "--cap-add" "MKNOD" ];
  };

  services.nginx.virtualHosts."docs.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
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
}
