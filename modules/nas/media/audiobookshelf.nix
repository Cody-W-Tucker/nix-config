{
  config,
  mkNginxVhost,
  ...
}:

{
  services.audiobookshelf = {
    enable = true;
    group = "media";
    # Local-only binding; exposed through the Nginx vhost below.
    host = "127.0.0.1";
    port = 8091;
  };

  services.nginx.virtualHosts = mkNginxVhost {
    host = "audiobooks.homehub.tv";
    port = config.services.audiobookshelf.port;
    # Audiobookshelf pushes playback/scanner updates over websockets.
    proxyWebsockets = true;
    # Prevent 413 Request Entity Too Large errors on large uploads (10 GiB).
    locationExtraConfig = ''
      client_max_body_size 10240M;
    '';
  };
}
