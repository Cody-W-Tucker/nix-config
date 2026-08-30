{
  config,
  lib,
  pkgs,
  mkNginxVhost,
  ...
}:

let
  pkg = pkgs.callPackage ../../packages/gods-eye-view { };
  nodejs = pkgs.nodejs_24;
  cfg = config.services.gods-eye-view;
in
{
  options.services.gods-eye-view = {
    enable = lib.mkEnableOption "God's Eye View (Vite dev server)";
  };

  # Activated on NAS by default; set services.gods-eye-view.enable = false to disable.
  config = lib.mkMerge [
    { services.gods-eye-view.enable = lib.mkDefault true; }
    (lib.mkIf cfg.enable {
      # Dedicated system user for the service (used for SOPS secret ownership too).
      users.users.gods-eye-view = {
        isSystemUser = true;
        group = "gods-eye-view";
        description = "God's Eye View service user";
      };
      users.groups.gods-eye-view = { };

      # SOPS env file in systemd EnvironmentFile format (KEY=VALUE lines).
      # Populate it via `sops edit <secrets-file>` — see the module comment below.
      sops.secrets."gods-eye-view-env" = {
        owner = "gods-eye-view";
        group = "gods-eye-view";
        mode = "0400";
      };

      # Persistent cache directories. Vite writes .gev-cache, node_modules/.vite
      # and node_modules/.vite-temp under process.cwd(); the package symlinks
      # each into this StateDirectory so the (read-only) store stays immutable
      # while the caches remain writable across rebuilds.
      systemd.tmpfiles.rules = [
        "d /var/lib/gods-eye-view/.gev-cache 0700 gods-eye-view gods-eye-view -"
        "d /var/lib/gods-eye-view/.vite 0700 gods-eye-view gods-eye-view -"
        "d /var/lib/gods-eye-view/.vite-temp 0700 gods-eye-view gods-eye-view -"
      ];

      systemd.services.gods-eye-view = {
        description = "God's Eye View (Vite dev server)";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "nginx.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "nginx.service" ];
        serviceConfig = {
          Type = "simple";
          User = "gods-eye-view";
          Group = "gods-eye-view";
          WorkingDirectory = "${pkg}/share/gods-eye-view";
          # Run the Vite dev server directly (not `vite preview`): upstream brokers
          # and proxies third-party APIs via Vite's configureServer. Bind strictly
          # to loopback; Nginx terminates TLS and proxies on 127.0.0.1:4173.
          ExecStart = "${nodejs}/bin/node ${pkg}/share/gods-eye-view/node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4173";
          EnvironmentFile = config.sops.secrets."gods-eye-view-env".path;
          Environment = [
            "HOST=127.0.0.1"
            "PORT=4173"
            "HOME=/var/lib/gods-eye-view"
            "PATH=${lib.makeBinPath [ nodejs ]}"
          ];
          StateDirectory = "gods-eye-view";
          # The store path (${pkg}/share/gods-eye-view) is immutable; .gev-cache,
          # node_modules/.vite and node_modules/.vite-temp are symlinked into the
          # StateDirectory above, so no write access to the store is required.
          # StateDirectory already makes /var/lib/gods-eye-view writable for the
          # service user.
          Restart = "on-failure";
          RestartSec = "5s";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          AmbientCapabilities = "";
        };
      };

      # Nginx reverse proxy (forceSSL + ACME like the rest of the fleet).
      # Upstream uses websockets (OpenAI Realtime voice + AISStream), so enable
      # websocket proxying.
      services.nginx.virtualHosts = mkNginxVhost {
        host = "watch.homehub.tv";
        port = 4173;
        proxyWebsockets = true;
        proxyHost = "127.0.0.1";
      };
    })
  ];
}

# How to populate the SOPS secret (add to your sops secrets file, then `update`):
#
#   gods-eye-view-env: |
#     GOOGLE_MAPS_API_KEY=your_key_here            # REQUIRED (Map Tiles API)
#     # Optional upstream proxy credentials:
#     CESIUM_ION_TOKEN=
#     OPENAI_API_KEY=
#     AISSTREAM_API_KEY=
#     FIRMS_MAP_KEY=
#     TOMTOM_API_KEY=
#     OPENSKY_CLIENT_ID=
#     OPENSKY_CLIENT_SECRET=
#     # GEV_RATELIMIT_GOOGLE_PER_MIN=60
#     # GEV_RATELIMIT_OPENAI_PER_MIN=30
