{
  config,
  pkgs,
  mkNginxVhost,
  ...
}:

let
  # Shelfmark's default Flask port, verified free on this host (`ss -tlnp`
  # and no references in the config). The container runs with host
  # networking (see extraOptions below), so Flask binds 0.0.0.0:8084
  # directly on the host stack — reachable on every host interface,
  # gated by the host firewall. Nginx terminates TLS for
  # shelfmark.homehub.tv and proxies to 127.0.0.1:8084.
  port = 8084;
in
{
  users.users.shelfmark = {
    isSystemUser = true;
    group = "shelfmark";
    # Static UID so the container env (PUID) can reference it. Verified
    # unused on this host at setup time.
    uid = 340;
    description = "Shelfmark book/audiobook downloader";
  };
  users.groups.shelfmark = { };

  # Directories:
  # - /var/lib/shelfmark holds Shelfmark's database, settings, and cover
  #   cache (mounted at /config). Owned by the service user; group media
  #   so the container process (which runs as PUID:PGID = shelfmark:media
  #   via the upstream entrypoint's root startup flow) can write it. On
  #   the root filesystem, so generic tmpfiles ordering is safe here.
  # - /mnt/media/Downloads/Shelfmark is the ebook staging destination,
  #   created by the shelfmark-dirs oneshot below rather than tmpfiles:
  #   systemd-tmpfiles-setup.service has no ordering against
  #   mnt-media.mount, so the directory could be created on the root
  #   filesystem and then shadowed by the mount, leaving the container
  #   bind-mounting a bare rootfs directory while the real directory sits
  #   hidden under the mountpoint. By design Shelfmark must NOT deliver
  #   into /mnt/media/Books: Calibre's library is managed by its own
  #   database, and files dropped there would never be imported into
  #   Calibre-Web. Ebooks land here instead for manual intake.
  # - Audiobooks go to the existing Audiobookshelf library, which scans
  #   them directly. setgid keeps new files group-owned by `media`.
  systemd.tmpfiles.rules = [
    "d /var/lib/shelfmark 0750 shelfmark media - -"
  ];

  # Create the ebook staging directory on the mounted media filesystem.
  # Runs on every container start, so ownership (root:media) and mode
  # (2775, setgid) are re-asserted across restarts and image upgrades
  # instead of being a one-time tmpfiles effect.
  systemd.services.shelfmark-dirs = {
    description = "Create Shelfmark staging directory on the mounted media filesystem";
    after = [ "mnt-media.mount" ];
    requires = [ "mnt-media.mount" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.coreutils}/bin/mkdir -p /mnt/media/Downloads/Shelfmark"
        "${pkgs.coreutils}/bin/chown root:media /mnt/media/Downloads/Shelfmark"
        "${pkgs.coreutils}/bin/chmod 2775 /mnt/media/Downloads/Shelfmark"
      ];
    };
  };

  virtualisation.oci-containers.containers.shelfmark = {
    autoStart = true;
    # v1.3.15 is the verified latest stable release (GitHub, 2026-09-02);
    # digest taken from the ghcr.io OCI manifest index. Full image (not
    # -lite): universal search needs the built-in browser for
    # Cloudflare-protected sources, which -lite requires external
    # FlareSolverr for.
    image = "ghcr.io/calibrain/shelfmark:v1.3.15@sha256:9602290324993c801b319d3166b202b96bd9039af2416f0916dae03a5bdca815";
    environment = {
      # The upstream entrypoint creates an in-container user from
      # PUID/PGID and drops privileges via gosu (root startup flow,
      # verified in entrypoint.sh at v1.3.15). PGID is the media
      # group's GID, pinned in modules/nas/media/default.nix, so the
      # container can write the setgid media directories.
      PUID = toString config.users.users.shelfmark.uid;
      PGID = toString config.users.groups.media.gid;

      CONFIG_DIR = "/config";
      FLASK_HOST = "0.0.0.0";
      FLASK_PORT = toString port;
      TZ = "America/Chicago";

      # Consumed by the upstream entrypoint (UMASK_VALUE=${UMASK:-0022}).
      # 002 makes delivered files group-writable so the media group can
      # manage them in the shared media tree; pairs with the setgid
      # destination directories.
      UMASK = "002";

      # Search across all configured sources.
      SEARCH_MODE = "universal";

      # Ebook destination: staging dir only (see tmpfiles above).
      INGEST_DIR = "/books";
      # Audiobook destination: Audiobookshelf scans this library.
      DESTINATION_AUDIOBOOK = "/audiobooks";

      # Navigation links only — Shelfmark has no Calibre API integration;
      # it never writes into the Calibre-managed /mnt/media/Books library.
      CALIBRE_WEB_URL = "https://books.homehub.tv";
      AUDIOBOOK_LIBRARY_URL = "https://audiobooks.homehub.tv";

      # Served behind HTTPS via the Nginx vhost below.
      SESSION_COOKIE_SECURE = "true";
    };
    volumes = [
      "/var/lib/shelfmark:/config"
      # The /books staging mount is where Shelfmark delivers files, but
      # Shelfmark also inspects Transmission's reported completed paths.
      # Transmission reports the *host* path (e.g.
      # /mnt/media/Downloads/Shelfmark/...), and Shelfmark opens that
      # path inside the container — so the container must see the
      # identical source path, not a differently-named mount. Hence the
      # whole Downloads tree is bind-mounted at the same path.
      "/mnt/media/Downloads:/mnt/media/Downloads"
      "/mnt/media/Downloads/Shelfmark:/books"
      "/mnt/media/AudioBookShelf:/audiobooks"
    ];
    # Host networking (same pattern as modules/nas/paperless-gpt.nix):
    # the container shares the host network namespace, so `ports`
    # publishing would be ignored and is dropped. Required so Shelfmark
    # can reach Prowlarr on the host loopback at http://localhost:9696.
    # Tradeoff vs. the old loopback port mapping: Flask
    # (FLASK_HOST = 0.0.0.0) now binds 8084 on every host interface
    # instead of loopback-only. The Nginx vhost below still proxies to
    # 127.0.0.1:8084, so its target is unchanged.
    extraOptions = [ "--network=host" ];
  };

  # Order the container after the /mnt/media mount and the staging-dir
  # oneshot, otherwise Docker can start first and bind-mount bare
  # directories from the root filesystem. Requires (not just After) the
  # oneshot so a failed mount takes the container down with it instead of
  # letting it bind-mount a bare rootfs path. Unit name follows the
  # generated oci-containers unit (docker backend →
  # docker-shelfmark.service).
  systemd.services."${config.virtualisation.oci-containers.backend}-shelfmark" = {
    after = [
      "mnt-media.mount"
      "shelfmark-dirs.service"
    ];
    requires = [
      "mnt-media.mount"
      "shelfmark-dirs.service"
    ];
  };

  # Verified in entrypoint.sh at v1.3.15: gunicorn runs with
  # `--worker-class geventwebsocket.gunicorn.workers.GeventWebSocketWorker`
  # and Socket.IO expects WebSocket upgrades, so websocket proxying is
  # required for live updates.
  services.nginx.virtualHosts = mkNginxVhost {
    host = "shelfmark.homehub.tv";
    inherit port;
    proxyWebsockets = true;
  };
}
