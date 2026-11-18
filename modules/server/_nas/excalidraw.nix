{
  config,
  mkNginxVhost,
  ...
}:

let
  inherit (config.codyos.site) domain;
in
{
  virtualisation.oci-containers.containers.excalidraw = {
    image = "excalidraw/excalidraw:latest";
    environment = {
      TZ = config.time.timeZone;
    };
    ports = [
      "127.0.0.1:2919:80"
    ];
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "draw.${domain}";
    port = 2919;
    locationExtraConfig = ''
      client_max_body_size 10M; # Allow uploads up to 10MB (adjust as needed)
    '';
  };
}
