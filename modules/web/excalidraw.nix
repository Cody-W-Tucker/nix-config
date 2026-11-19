{
  den.aspects.excalidraw.nixos =
    {
      config,
      mkNginxVhost,
      ...
    }:

    let
      inherit (config.codyos.site) domain;
    in
    {
      codyos.homepage.cards.ExcaliDraw = {
        group = "Tools";
        order = 40;
        card = {
          href = "https://draw.${domain}";
          icon = "excalidraw";
          description = "Whiteboard";
        };
      };

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
          client_max_body_size 10M;
        '';
      };
    };
}
