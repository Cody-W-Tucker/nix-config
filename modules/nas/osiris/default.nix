{
  config,
  pkgs,
  lib,
  inputs,
  mkNginxVhost,
  ...
}:
let
  cfg = config.services.osiris;
  pkg = import ./package.nix { inherit pkgs lib inputs; };
in
{
  options.services.osiris = {
    enable = lib.mkEnableOption "the Osiris dashboard with the Pythia oracle overlay";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Interface the Osiris server binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port the Osiris server listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable the Pythia → Osiris intake ONLY when Osiris is actually
    # configured. Left null (disabled) otherwise.
    services.pythia.osirisUrl = "http://127.0.0.1:${toString cfg.port}";

    users.users.osiris = {
      isSystemUser = true;
      group = "osiris";
      description = "Osiris dashboard";
      home = "/var/lib/osiris";
    };
    users.groups.osiris = { };

    systemd.services.osiris = {
      description = "Osiris dashboard + Pythia oracle overlay (Next.js standalone)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "pythia.service"
      ];
      wants = [ "pythia.service" ];
      serviceConfig = {
        Type = "simple";
        User = "osiris";
        Group = "osiris";
        StateDirectory = "osiris";
        # Writable cache dir for Next's runtime cache (.next/cache). Created on
        # service start, owned by the osiris user; the built server symlinks
        # .next/cache -> /var/cache/osiris so the read-only store is never written.
        CacheDirectory = "osiris";
        CacheDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/osiris";
        ExecStart = "${pkgs.nodejs_22}/bin/node ${pkg}/server.js";
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = [
          "NODE_ENV=production"
          "PORT=${toString cfg.port}"
          "HOSTNAME=${cfg.host}"
          # Proxied to the engine by src/app/api/engine/[...path]/route.ts.
          "PYTHIA_ENGINE_URL=http://127.0.0.1:8088"
        ];

        # ── Hardening (Node-compatible) ──
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectClock = true;
        ProtectProc = "invisible";
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectHostname = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        LockPersonality = true;
        # Node needs to exec + map; it writes only under StateDirectory.
        MemoryDenyWriteExecute = false;
        ReadWritePaths = [
          "/var/lib/osiris"
          "/var/cache/osiris"
        ];
      };
    };

    # SSE streaming → buffering off, long timeouts.
    services.nginx.virtualHosts = mkNginxVhost {
      host = "osiris.homehub.tv";
      port = cfg.port;
      proxyWebsockets = true;
      locationExtraConfig = ''
        proxy_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };
}
