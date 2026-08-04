{
  config,
  inputs,
  lib,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  cfg = config.services.buzz-relay;
  port = 3100;
  stateDir = "/var/lib/buzz-relay";
  # Upstream contract: BUZZ_GIT_REPO_PATH must point at a writable
  # directory where buzz-relay clones/mirrors git repositories as a
  # local workspace cache. It is NOT authoritative persistent state
  # (authoritative repo state belongs in object storage); it is the
  # local checkout the relay reads from on webhook hooks.
  gitRepoPath = "${stateDir}/git-repo";
  relayPublicUrl = "wss://buzz.homehub.tv";
  buzzPackage = inputs.buzz.packages.${pkgs.stdenv.hostPlatform.system}.buzz-relay;
in
{
  # Opt-in: the whole stack below depends on SOPS secrets
  # (buzz-redis-*, buzz-s3-*, buzz-relay-private-key,
  # buzz-hmac-secret, and the seaweedfs-s3-config template). Enable it
  # only after those secrets have been added to the host's SOPS store.
  options.services.buzz-relay.enable = lib.mkEnableOption "Buzz relay stack";

  config = lib.mkMerge [
    # ── Buzz CLI for admin/setup ────────────────────────────────────
    # Available independently of whether the relay service is enabled,
    # so operators can run `buzz` for setup/migration/admin tasks.
    {
      environment.systemPackages = [
        inputs.buzz.packages.${pkgs.stdenv.hostPlatform.system}.buzz-cli
      ];
    }

    # ── Relay stack (gated by enable) ──────────────────────────────
    (lib.mkIf cfg.enable {
      # ── SOPS secrets ─────────────────────────────────────────────
      # NOTE: buzz-s3-access-key / buzz-s3-secret-key hold a least-privilege
      # SeaweedFS S3 identity (NOT admin). See the operator bootstrap block
      # under systemd.services.seaweedfs below.
      sops.secrets."buzz-redis-password" = { };
      sops.secrets."buzz-redis-url" = { };
      sops.secrets."buzz-s3-endpoint" = { };
      sops.secrets."buzz-s3-bucket" = { };
      sops.secrets."buzz-s3-region" = { };
      sops.secrets."buzz-s3-access-key" = { };
      sops.secrets."buzz-s3-secret-key" = { };
      sops.secrets."buzz-relay-private-key" = { };
      sops.secrets."buzz-hmac-secret" = { };
      # SeaweedFS S3 config: JSON with least-privilege identity for bucket "buzz".
      # Built from the buzz-s3-access-key / buzz-s3-secret-key values.
      sops.templates."seaweedfs-s3-config" = {
        content = ''
          {
            "identities": [
              {
                "name": "buzz-relay",
                "credentials": [
                  {
                    "accessKey": "${config.sops.placeholder."buzz-s3-access-key"}",
                    "secretKey": "${config.sops.placeholder."buzz-s3-secret-key"}"
                  }
                ],
                "actions": [
                  "Read:buzz",
                  "Write:buzz",
                  "List:buzz",
                  "Tagging:buzz"
                ]
              }
            ]
          }
        '';
      };

      # ── PostgreSQL ───────────────────────────────────────────────
      # Peer authentication: the relay connects over the Unix socket and
      # the kernel-supplied Unix identity (`buzz`) is mapped to the
      # Postgres role of the same name, so no stored password is needed.
      # The DATABASE_URL below points at that socket and declares the
      # matching role, so `ensureUsers` and the runtime URI agree.
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_16;
        ensureDatabases = [ "buzz" ];
        ensureUsers = [
          {
            name = "buzz";
            ensureDBOwnership = true;
          }
        ];
      };

      # ── Redis ────────────────────────────────────────────────────
      services.redis.servers.buzz = {
        enable = true;
        port = 6380;
        requirePassFile = config.sops.secrets.buzz-redis-password.path;
      };

      # ── SeaweedFS (S3-compatible storage, local-only) ───────────
      # Single-node all-in-one (master + volume + filer + S3 gateway)
      # bound to 127.0.0.1 only so local services can reach it but nothing
      # external can. No firewall ports opened.
      #
      # ONE-TIME OPERATOR BOOTSTRAP (not automated here):
      #   SeaweedFS does not auto-create S3 buckets. After first deploy, an
      #   operator must create the `buzz` bucket and assign it to the
      #   `buzz-relay` identity. The `buzz-relay` identity in the S3 config
      #   has no Admin action, so it cannot create buckets itself
      #   (by design — least privilege).
      #
      #   Create the bucket and assign ownership via the SeaweedFS shell:
      #
      #     nix run nixpkgs#seaweedfs -- shell \
      #       -master=127.0.0.1:9333 -filer=127.0.0.1:8888 \
      #       <<<'s3.bucket.create -name buzz -owner buzz-relay'
      #
      #   The `-owner` value must match the `name` field in the S3 identity
      #   config above so that the non-admin buzz-relay credentials can
      #   access the bucket they own.
      #
      #   After creating the bucket, populate the SOPS placeholders:
      #     `buzz-s3-endpoint`  → "http://127.0.0.1:8333"
      #     `buzz-s3-bucket`    → "buzz"
      #     `buzz-s3-region`    → "us-east-1"
      #     `buzz-s3-access-key` and `buzz-s3-secret-key` must match the
      #     credentials rendered into the SeaweedFS S3 config template above.
      #
      #   Verify with:
      #     AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
      #     nix run nixpkgs#awscli2 -- s3 \
      #       --endpoint-url http://127.0.0.1:8333 \
      #       --region us-east-1 ls s3://buzz
      systemd.services.seaweedfs = {
        description = "SeaweedFS (master + volume + filer + S3 gateway)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        serviceConfig = {
          Type = "simple";
          User = "seaweedfs";
          Group = "seaweedfs";
          StateDirectory = "seaweedfs";
          StateDirectoryMode = "0750";
          Restart = "on-failure";
          RestartSec = "5s";

          # Load the S3 identity config from the SOPS template into
          # $CREDENTIALS_DIRECTORY so the process never sees plaintext on disk.
          LoadCredential = [
            "s3-config.json:${config.sops.templates."seaweedfs-s3-config".path}"
          ];

          # ── Hardening ──────────────────────────────────────────
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          # SeaweedFS must write to its StateDirectory.
          ReadWritePaths = [ "/var/lib/seaweedfs" ];
          # Allow binding to the configured ports.
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
        };

        # Use a script wrapper so $CREDENTIALS_DIRECTORY expands at runtime.
        # systemd's ExecStart passes the string literally; the shell wrapper
        # performs the variable substitution. Volume port 18080 avoids the
        # host's existing 0.0.0.0:8080 listener (master 9333, filer 8888,
        # S3 8333, and filer gRPC 18888 unchanged).
        script = ''
          exec ${pkgs.seaweedfs}/bin/weed server \
            -ip=127.0.0.1 \
            -dir=/var/lib/seaweedfs \
            -master.port=9333 \
            -volume.port=18080 \
            -filer \
            -filer.port=8888 \
            -s3 \
            -s3.port=8333 \
            -s3.port.grpc=8334 \
            -s3.config="$CREDENTIALS_DIRECTORY/s3-config.json"
        '';
      };

      # ── SeaweedFS dedicated system user ─────────────────────────
      users.users.seaweedfs = {
        isSystemUser = true;
        group = "seaweedfs";
        home = "/var/lib/seaweedfs";
      };
      users.groups.seaweedfs = { };

      # ── Buzz relay service ──────────────────────────────────────
      systemd.services.buzz-relay = {
        description = "Buzz Relay Server";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "postgresql.service"
          "redis-buzz.service"
          "seaweedfs.service"
        ];
        requires = [
          "postgresql.service"
          "redis-buzz.service"
          "seaweedfs.service"
        ];

        # Non-secret runtime config. Matches the exact env var names
        # expected by upstream buzz-relay.
        environment = {
          # Bind to all interfaces on the port nginx proxies to.
          BUZZ_BIND_ADDR = "0.0.0.0:${toString port}";
          # Public WebSocket URL clients use to reach this relay.
          RELAY_URL = relayPublicUrl;
          # Persistent workspace where buzz-relay clones git repos.
          # Created by tmpfiles rule below; owned by the service user.
          BUZZ_GIT_REPO_PATH = gitRepoPath;
          # SeaweedFS S3 gateway is S3-compatible and works with path-style
          # addressing; virtual-hosted style is NOT required and is less
          # portable against direct-endpoint configurations.
          BUZZ_S3_ADDRESSING_STYLE = "path";
          # CORS: Buzz's web UI is served from the same origin
          # (https://buzz.homehub.tv via the nginx vhost below), so
          # same-origin requests don't strictly need CORS. We still
          # pin the explicit allowed origin so any cross-origin caller
          # from the deployed frontend is accepted and nothing else.
          BUZZ_CORS_ORIGINS = "https://buzz.homehub.tv";
          # Reject unauthenticated hooks at the relay boundary.
          BUZZ_REQUIRE_AUTH_TOKEN = "true";
          BUZZ_AUTO_MIGRATE = "true";
          # Upstream relay keeps `/` as NIP-11/WebSocket by default.
          # Enabling this makes browser roots serve the web bundle while
          # NIP-11 clients (Accept: application/nostr+json) keep working.
          BUZZ_SERVE_GIT_WEB_GUI = "true";
          # Verified upstream value — do not change to "true"/"false".
          BUZZ_MESH = "on";
          # Shift health/metrics listeners off the upstream defaults
          # (8080/9102) to avoid host port conflicts on NAS.
          BUZZ_HEALTH_PORT = "18082";
          BUZZ_METRICS_PORT = "18083";
          # Peer-auth Postgres URI: Unix socket at /run/postgresql, role
          # `buzz` (matches the service User), database `buzz`. No
          # password — the kernel Unix identity satisfies pg_hba.conf.
          # Slashes inside the query value are valid URI content and are
          # NOT percent-escaped, so systemd never sees a `%` specifier.
          DATABASE_URL = "postgresql:///buzz?host=/run/postgresql&user=buzz";
        };

        serviceConfig = {
          Type = "simple";
          User = "buzz";
          Group = "buzz";
          StateDirectory = "buzz-relay";
          StateDirectoryMode = "0750";
          Restart = "on-failure";
          RestartSec = "5s";

          # Load secrets from SOPS files into $CREDENTIALS_DIRECTORY.
          # Alias names match the env var the wrapper script exports.
          LoadCredential = [
            "REDIS_URL:${config.sops.secrets.buzz-redis-url.path}"
            "BUZZ_S3_ENDPOINT:${config.sops.secrets.buzz-s3-endpoint.path}"
            "BUZZ_S3_BUCKET:${config.sops.secrets.buzz-s3-bucket.path}"
            "BUZZ_S3_REGION:${config.sops.secrets.buzz-s3-region.path}"
            "BUZZ_S3_ACCESS_KEY:${config.sops.secrets.buzz-s3-access-key.path}"
            "BUZZ_S3_SECRET_KEY:${config.sops.secrets.buzz-s3-secret-key.path}"
            "BUZZ_RELAY_PRIVATE_KEY:${config.sops.secrets.buzz-relay-private-key.path}"
            "BUZZ_GIT_HOOK_HMAC_SECRET:${config.sops.secrets.buzz-hmac-secret.path}"
          ];

          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ReadWritePaths = [
            stateDir
          ];
        };

        # Wrapper script loads secrets into env, then execs buzz-relay.
        # Non-secret env vars (BUZZ_BIND_ADDR, RELAY_URL, etc.) are
        # already in the process environment via `environment` above.
        script = ''
          export REDIS_URL="$(cat "$CREDENTIALS_DIRECTORY/REDIS_URL")"
          export BUZZ_S3_ENDPOINT="$(cat "$CREDENTIALS_DIRECTORY/BUZZ_S3_ENDPOINT")"
          export BUZZ_S3_BUCKET="$(cat "$CREDENTIALS_DIRECTORY/BUZZ_S3_BUCKET")"
          export BUZZ_S3_REGION="$(cat "$CREDENTIALS_DIRECTORY/BUZZ_S3_REGION")"
          export BUZZ_S3_ACCESS_KEY="$(cat "$CREDENTIALS_DIRECTORY/BUZZ_S3_ACCESS_KEY")"
          export BUZZ_S3_SECRET_KEY="$(cat "$CREDENTIALS_DIRECTORY/BUZZ_S3_SECRET_KEY")"
          export BUZZ_RELAY_PRIVATE_KEY="$(cat "$CREDENTIALS_DIRECTORY/BUZZ_RELAY_PRIVATE_KEY")"
          export BUZZ_GIT_HOOK_HMAC_SECRET="$(cat "$CREDENTIALS_DIRECTORY/BUZZ_GIT_HOOK_HMAC_SECRET")"

          # Derive the bootstrap owner from the protected relay credential.
          export RELAY_OWNER_PUBKEY="$(printf '%s' "$BUZZ_RELAY_PRIVATE_KEY" | ${pkgs.nak}/bin/nak key public)"

          exec ${buzzPackage}/bin/buzz-relay
        '';
      };

      # Ensure the git-repo workspace exists and is owned by the service
      # user. StateDirectory creates ${stateDir} itself; this rule creates
      # the ${stateDir}/git-repo subdir the first boot after deploy.
      systemd.tmpfiles.rules = [
        "d '${gitRepoPath}' 0750 buzz buzz -"
      ];

      # ── Dedicated system user ───────────────────────────────────
      users.users.buzz = {
        isSystemUser = true;
        group = "buzz";
        home = stateDir;
      };
      users.groups.buzz = { };

      # ── Nginx vhost with WebSocket support ──────────────────────
      # Proxies https://buzz.homehub.tv → 127.0.0.1:3100; BUZZ_BIND_ADDR
      # above listens on 0.0.0.0:3100 so the proxy reaches it.
      services.nginx.virtualHosts = mkNginxVhost {
        host = "buzz.homehub.tv";
        inherit port;
        proxyWebsockets = true;
        locationExtraConfig = ''
          client_max_body_size 100M;
        '';
      };
    })
  ];
}
