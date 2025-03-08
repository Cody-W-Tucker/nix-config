let
  HOST = "pdf.homehub.tv";
  PORT = 44302;
in
{
  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = PORT;
      INSTALL_BOOK_AND_ADVANCED_HTML_OPS = "true";
    };
  };

  # Nginx reverse proxy to Stirling PDF with custom port
  services.nginx.virtualHosts.${HOST} = {
    useACMEHost = "homehub.tv";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString PORT}/";
      proxyWebsockets = true;
      # The default value 1M might be a little too small.
      extraConfig = ''
        client_max_body_size 100M;
      '';
    };
  };
}
