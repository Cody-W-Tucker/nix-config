{
  pkgs,
  config,
  mkMediaVhost,
  ...
}:

{
  # Calibre web for reading Books (with Kobo sync support)
  services.calibre-web = {
    enable = true;
    group = "media";
    listen.port = 8083;
    options.calibreLibrary = "/mnt/media/Books";
    package = pkgs.calibre-web.overridePythonAttrs (oldAttrs: {
      dependencies = oldAttrs.dependencies ++ oldAttrs.optional-dependencies.kobo;
    });
  };

  # Calibre content server for Readarr metadata lookups
  services.calibre-server = {
    enable = true;
    group = "media";
    libraries = [ "/mnt/media/Books" ];
    port = 7007;
    openFirewall = true;
    extraFlags = [ "--trusted-ips=127.0.0.1,::1" ];
  };

  # Open Port for kobo sync
  networking.firewall.allowedTCPPorts = [ 8083 ];

  services.nginx.virtualHosts = mkMediaVhost {
    host = "books.homehub.tv";
    port = 8083;
    extraConfig = ''
      # Kobo sync requires large headers
      proxy_busy_buffers_size   1024k;
      proxy_buffers   4 512k;
      proxy_buffer_size   1024k;
      proxy_set_header X-Scheme $scheme;
    '';
  };
}
