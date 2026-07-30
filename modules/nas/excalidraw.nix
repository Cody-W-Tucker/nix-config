{
  virtualisation.oci-containers.containers.excalidraw = {
    autoStart = true;
    image = "excalidraw/excalidraw:latest";
    environment = {
      TZ = "America/Chicago";
    };
    ports = [
      "2919:80"
    ];
  };

  services.nginx.virtualHosts = {
    "draw.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/".proxyPass = "http://localhost:2919";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 10M; # Allow uploads up to 10MB (adjust as needed)
      '';
      kTLS = true;
    };
  };
}
