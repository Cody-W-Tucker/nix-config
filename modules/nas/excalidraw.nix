{
  mkNginxVhost,
  ...
}:

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

  services.nginx.virtualHosts = mkNginxVhost {
    host = "draw.homehub.tv";
    port = 2919;
    locationExtraConfig = ''
      client_max_body_size 10M; # Allow uploads up to 10MB (adjust as needed)
    '';
  };
}
