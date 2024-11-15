{ config, ... }:

{
  sops.secrets."miniflux/ADMIN_USERNAME" = { };
  sops.secrets."miniflux/ADMIN_PASSWORD" = { };

  sops.templates."miniflux-credentials".content = ''
    ADMIN_USERNAME=${config.sops.placeholder."miniflux/ADMIN_USERNAME"}
    ADMIN_PASSWORD=${config.sops.placeholder."miniflux/ADMIN_PASSWORD"}
  '';

  services = {
    # Miniflux RSS reader
    miniflux = {
      enable = true;
      config = {
        CLEANUP_FREQUENCY = 48;
        LISTEN_ADDR = "localhost:7777";
        BASE_URL = "https://rss.homehub.tv";
      };
      adminCredentialsFile = config.sops.templates."miniflux-credentials".path;
    };
    nginx.virtualHosts."rss.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://localhost:7777";
      };
    };

    # Calibre-web ebook reader
    calibre-web = {
      enable = true;
      group = "media";
      options.enableBookUploading = true;
      options.enableBookConversion = true;
      options.enableKepubify = true;
    };
    nginx.virtualHosts."ebook.homehub.tv" = {
      forceSSL = true;
      useACMEHost = "homehub.tv";
      locations."/" = {
        proxyPass = "http://localhost:8083";
        extraConfig = ''
          client_max_body_size 500M;
          proxy_busy_buffers_size 1024k;
          proxy_buffers 4 512k;
          proxy_buffer_size 1024k;
        '';
      };
    };
  };
}
