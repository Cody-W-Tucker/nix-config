{ pkgs, ... }:
{
  services = {
    # Calibre web for reading Books (with Kobo sync support)
    calibre-web = {
      enable = true;
      group = "media";
      listen.port = 8083;
      options.calibreLibrary = "/mnt/media/Books";
      package = pkgs.calibre-web.overridePythonAttrs (oldAttrs: {
        dependencies = oldAttrs.dependencies ++ oldAttrs.optional-dependencies.kobo;
      });
    };
  };

  # NGINX
  services.nginx.virtualHosts."books.homehub.tv" = {
    forceSSL = true;
    useACMEHost = "homehub.tv";
    locations."/" = {
      proxyPass = "http://localhost:8083";
      proxyWebsockets = true;
      extraConfig = ''
        # Kobo sync requires large headers
        proxy_busy_buffers_size   1024k;
        proxy_buffers   4 512k;
        proxy_buffer_size   1024k;
        proxy_set_header X-Scheme $scheme;
      '';
    };
    kTLS = true;
  };

  # Open Port for kobo sync
  networking.firewall.allowedTCPPorts = [ 8083 ];
}
