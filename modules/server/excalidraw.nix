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
      locations."/".proxyPass = "http://127.0.0.1:2919";
    };
  };
}