{
  config,
  inputs,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  yaml = pkgs.formats.yaml { };
  litellmModels = import ./models.nix;

  # OpenCode Go upstream models. LiteLLM routes these to the hosted
  # opencode.ai/zen/go API instead of ChatGPT. The upstream API shape
  # selects the provider adapter, which appends its own request path:
  #   - anthropic → /v1/messages
  #   - openai    → /v1/chat/completions
  # Auth is supplied at runtime via OPENCODE_GO_API_KEY in litellm-env.
  opencodeGoModels = {
    "hy3" = {
      provider = "openai";
      api_base = "https://opencode.ai/zen/go/v1";
      mode = "chat";
    };
  };

  # Local llama-swap models (host-managed). When llama-swap is enabled on
  # the same host, expose its enabled model IDs through LiteLLM as
  # OpenAI-compatible routes to the llama-swap OpenAI endpoint on localhost.
  # Model aliases equal the llama-swap model keys (the id llama-swap serves
  # and the --alias the backend registers).
  llamaSwapState = builtins.tryEval config.services.llama-swap.enable;
  llamaSwapEnabled = llamaSwapState.success && llamaSwapState.value;
  llamaSwapPort = if llamaSwapEnabled then config.services.llama-swap.port else 8081;

  mkLlamaSwapEntry = id: {
    model_name = id;
    litellm_params = {
      model = "openai/${id}";
      api_base = "http://127.0.0.1:${toString llamaSwapPort}/v1";
      api_key = "sk-none";
    };
  };

  llamaSwapModelList = map mkLlamaSwapEntry (
    if llamaSwapEnabled then config.services.llama-swap.enabledModels else [ ]
  );

  mkModelEntry =
    id:
    if builtins.hasAttr id opencodeGoModels then
      let
        cfg = opencodeGoModels.${id};
      in
      {
        model_name = id;
        litellm_params = {
          model = "${cfg.provider}/${id}";
          api_base = cfg.api_base;
          api_key = "os.environ/OPENCODE_GO_API_KEY";
        };
        model_info = {
          mode = cfg.mode;
        };
      }
    else
      {
        model_name = id;
        litellm_params = {
          model = "chatgpt/${id}";
        };
        model_info = {
          mode = "responses";
        };
      };

  # LiteLLM proxy configuration — generated into the store.
  litellmConfig = yaml.generate "litellm-config.yaml" {
    model_list = (map mkModelEntry litellmModels) ++ llamaSwapModelList;
    general_settings = {
      master_key = "os.environ/LITELLM_MASTER_KEY";
      database_url = "os.environ/DATABASE_URL";
    };
    litellm_settings = {
      # Drop unrecognized provider params rather than failing.
      drop_params = true;
      additional_drop_params = [ "previous_response_id" ]; # litellm doesn't handle this.
      # OpenTelemetry is Langfuse's current ingestion path. The legacy
      # `langfuse` callback uses an obsolete event API rejected by Langfuse v4.
      success_callback = [ "langfuse_otel" ];
      failure_callback = [ "langfuse_otel" ];
    };
  };
in
{
  imports = [
    inputs.litellm-nix.nixosModules.default
  ];

  # ── PostgreSQL (host-managed) ─────────────────────────────────
  # LiteLLM's Prisma-backed persistence needs a durable database
  # and role. The fork's `manageLocalPostgresql = true` (default)
  # handles ordering and applies LITELLM_DATABASE_PASSWORD to the
  # local `litellm` role — it does NOT bootstrap postgres itself.
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "litellm" ];
    ensureUsers = [
      {
        name = "litellm";
        ensureDBOwnership = true;
      }
    ];
  };

  # ── Compressed nightly backup of the LiteLLM database only ───
  # Scoped to the litellm DB to keep other host databases out of
  # this rotation. Output goes to a dedicated ZFS dataset on the
  # backup pool (mounted at /mnt/litellm-backups) so dumps are
  # isolated from general appdata and written only when the pool
  # is actually mounted.
  services.postgresqlBackup = {
    enable = true;
    databases = [ "litellm" ];
    location = "/mnt/litellm-backups";
    compression = "zstd";
  };

  # ── ZFS dataset for LiteLLM backups ──────────────────────────
  # backup/litellm → /mnt/litellm-backups. Owned by postgres:postgres
  # with 0700 so only the database superuser can read/write dumps.
  # Follows the same idempotent-create-if-missing convention used
  # for the NFS workspace datasets in modules/nas/nfs.nix.
  systemd.services."zfs-create-backup-litellm" = {
    description = "Ensure ZFS dataset backup/litellm exists and is mounted at /mnt/litellm-backups";
    wantedBy = [ "multi-user.target" ];
    before = [
      "postgresqlBackup-litellm.service"
      "shutdown.target"
    ];
    after = [ "zfs-import-backup.service" ];
    requires = [ "zfs-import-backup.service" ];
    conflicts = [ "shutdown.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! ${pkgs.zfs}/bin/zfs list -H -o name backup/litellm &>/dev/null; then
        ${pkgs.zfs}/bin/zfs create -o mountpoint=/mnt/litellm-backups backup/litellm
      else
        ${pkgs.zfs}/bin/zfs set mountpoint=/mnt/litellm-backups backup/litellm
      fi
      ${pkgs.zfs}/bin/zfs mount backup/litellm 2>/dev/null || true
      # postgres owns the dump directory; no group/other access.
      ${pkgs.coreutils}/bin/chown postgres:postgres /mnt/litellm-backups
      ${pkgs.coreutils}/bin/chmod 0700 /mnt/litellm-backups
    '';
  };

  # The backup unit is generated by the postgresqlBackup module;
  # bind it to the ZFS dataset service so a failed mount cannot
  # silently write dumps into the unmounted parent directory.
  systemd.services."postgresqlBackup-litellm" = {
    requires = [ "zfs-create-backup-litellm.service" ];
    after = [ "zfs-create-backup-litellm.service" ];
  };

  # ── LiteLLM (database-backed proxy + admin UI) ──────────────
  # The fork package builds LiteLLM with Prisma 6, a generated
  # Prisma client, migrations, and UI assets; migrations run in
  # litellm-migrations.service and the main service starts after.
  # State lives in /var/lib/litellm (stateDir).
  services.litellm-nix = {
    enable = true;
    host = "127.0.0.1";
    port = 8090;
    requireChatgptAuth = true;
    enableChatgptLogin = true;
    enableCodexUsage = true;
    configFile = litellmConfig;
    # Orders after postgresql.service and applies the password
    # from databaseEnvFile to the local `litellm` role.
    manageLocalPostgresql = true;
    databaseEnvFile = config.sops.secrets."litellm-database-env".path;
    # OPENCODE_GO_API_KEY is sourced from the canonical `opencode-api-key`
    # secret (same source Hermes uses) so the hy3 model actually receives
    # an auth token. `litellm-env` stays the general env file; this is
    # additive and does not touch whatever else `litellm-env` provides.
    envFiles = [
      config.sops.secrets."litellm-env".path
      config.sops.secrets."litellm-langfuse-env".path
      config.sops.templates."opencode-go-api-key-env".path
    ];
    extraEnvironment = {
      STORE_PROMPTS_IN_SPEND_LOGS = "true";
      # Internal Langfuse endpoint. LiteLLM runs on the host; the Langfuse
      # web container publishes to the host loopback at 127.0.0.1:3000, so
      # this is the directly routable internal URL (no DNS/TLS dependency).
      LANGFUSE_HOST = "http://127.0.0.1:3000";
      LANGFUSE_OTEL_HOST = "http://127.0.0.1:3000";
      LANGFUSE_TRACING_ENVIRONMENT = "production";
    };
  };

  # ── SOPS secrets ──────────────────────────────────────────────
  sops.secrets."litellm-env" = { };
  sops.secrets."litellm-database-env" = { };

  # Langfuse project credentials for LiteLLM tracing. Raw env-file secret
  # (same shape as `litellm-env`); the decrypted file must contain the
  # project-scoped keys generated in the Langfuse UI (Settings → Projects):
  #   LANGFUSE_PUBLIC_KEY=pk-lf-...
  #   LANGFUSE_SECRET_KEY=sk-lf-...
  # Add the secret for the `nas` host in the private secrets repo's
  # .sops.yaml recipients, then populate it with `sops edit`.
  sops.secrets."litellm-langfuse-env" = { };

  # Auth for the opencode.ai/zen/go upstream (hy3). Derived from the
  # same `opencode-api-key` secret Hermes uses, rendered into its own
  # env file so LiteLLM receives OPENCODE_GO_API_KEY by name.
  sops.templates."opencode-go-api-key-env" = {
    content = ''
      OPENCODE_GO_API_KEY=${config.sops.placeholder."opencode-api-key"}
    '';
  };

  # ── Reverse proxy ─────────────────────────────────────────────
  # ai.homehub.tv → LiteLLM upstream on 127.0.0.1:8090.
  # HTTP/SSE: buffering off, long upstream read/send timeouts.
  # No websocket proxy. No Tailscale allowlist — matches prior
  # reverse-proxy behavior exactly.
  services.nginx.virtualHosts = mkNginxVhost {
    host = "ai.homehub.tv";
    port = 8090;
    proxyWebsockets = false;
    locationExtraConfig = ''
      proxy_buffering off;
      proxy_read_timeout 600s;
      proxy_send_timeout 600s;
    '';
  };
}
