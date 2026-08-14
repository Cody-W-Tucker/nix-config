{
  config,
  pkgs,
  mkNginxVhost,
  ...
}:

{
  # Secret must be populated via `sops set` (or equivalent). The file is
  # expected to contain the raw secret key base string (a single line of
  # 128+ hex characters, as produced by `rails secret`).
  sops.secrets."dawarich-secret-key-base" = { };

  services.dawarich = {
    enable = true;
    # The upstream module's built-in `configureNginx = true` only emits an
    # HTTP :80 vhost, which collides with the NAS login page when the HTTPS
    # vhost is resolved. Manage the Nginx proxy ourselves with mkNginxVhost
    # so we get forceSSL + ACME like the rest of the fleet.
    webPort = 3004;
    localDomain = "tracker.homehub.tv";
    configureNginx = false;
    secretKeyBaseFile = config.sops.secrets."dawarich-secret-key-base".path;
  };

  # Serve Dawarich's precompiled static assets directly from the package
  # store, falling back to the Rails app for dynamic routes and WebSocket
  # connections. The @dawarich named location proxies misses upstream.
  services.nginx.virtualHosts = mkNginxVhost {
    host = "tracker.homehub.tv";
    locations = {
      "/" = {
        root = "${pkgs.dawarich}/public";
        tryFiles = "$uri @dawarich";
      };
      "@dawarich" = {
        proxyPass = "http://127.0.0.1:3004";
        proxyWebsockets = true;
        recommendedProxySettings = true;
      };
    };
  };
}
