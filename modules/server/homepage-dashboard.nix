{

  services = {
    nginx.virtualHosts."homehub.tv" = {
      useACMEHost = "homehub.tv";
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:8082";
    };

    homepage-dashboard = {

      # These options were already present in my configuration.

      enable = true;
      listenPort = 8082;

      # https://gethomepage.dev/latest/configs/settings/

      settings = { };


      # https://gethomepage.dev/latest/configs/bookmarks/

      bookmarks = [ ];


      # https://gethomepage.dev/latest/configs/services/

      services = [ ];


      # https://gethomepage.dev/latest/configs/service-widgets/

      widgets = [ ];


      # https://gethomepage.dev/latest/configs/docker/

      docker = { };

    };
  };

}
