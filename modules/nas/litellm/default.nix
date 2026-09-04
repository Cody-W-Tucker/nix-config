{
  config,
  inputs,
  lib,
  mkNginxVhost,
  pkgs,
  ...
}:

let
  # Go routes derive directly from ./go-catalog.nix. The explicit ChatGPT routes
  # below use the gpt-5.6-* subset of the OpenCode catalog so visible IDs and
  # proxy aliases remain aligned.
  chatgptModelIds = lib.filter (id: lib.hasPrefix "gpt-5.6-" id) (import ./models.nix);

  # sops-nix owns sops-install-secrets.service only when useSystemdActivation is
  # on; there is no sops-nix.service, so the dependency is conditional.
  sopsUnits = lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";

  # Upstream services.litellm ships only on nixpkgs-unstable (1.97.0).
  litellmPkg = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.litellm;

  # Build the langfuse_otel runtime from the same unstable python3 litellm is built
  # against (litellmPkg has no .python attr).
  openTelemetryPython =
    inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.python3.withPackages
      (
        pythonPackages: with pythonPackages; [
          opentelemetry-api
          opentelemetry-sdk
          opentelemetry-exporter-otlp-proto-http
        ]
      );

  # OpenCode Go model catalog — the SINGLE SOURCE OF TRUTH for Go endpoint model
  # IDs, their LiteLLM provider adapter, and protocol mode. Imported (not
  # duplicated) by ./models.nix so the OpenCode client sees the same IDs. Every
  # entry is a live Go model; provider + mode come from the official OpenCode Go
  # Endpoints table (see ./go-catalog.nix for the evidence and for the documented
  # exclusion of gpt-5.6-luna, the sole Go id still routed by the ChatGPT
  # wildcard). The provider determines the required Go api_base; auth
  # (OPENCODE_GO_API_KEY) is shared by all Go models and is applied below.
  goCatalog = import ./go-catalog.nix;

  # One explicit, protocol-correct route per catalog id. The provider adapter
  # appends its own request path. Anthropic includes /v1/messages, while OpenAI
  # appends chat/completions or responses to its versioned base. This is a set of distinct routes —
  # NOT a wildcard — so they cannot mix credentials/upstreams with the ChatGPT
  # or llama-swap routes.
  mkOpencodeGoEntry =
    id:
    let
      cfg = goCatalog.${id};
    in
    {
      model_name = id;
      litellm_params = {
        model = "${cfg.provider}/${id}";
        # OpenAI's client does not add /v1; Anthropic's client does.
        api_base =
          if cfg.provider == "anthropic" then
            "https://opencode.ai/zen/go"
          else
            "https://opencode.ai/zen/go/v1";
        api_key = "os.environ/OPENCODE_GO_API_KEY";
      };
      model_info = {
        inherit (cfg) mode;
      };
    };

  opencodeGoEntries = map mkOpencodeGoEntry (builtins.attrNames goCatalog);

  # ChatGPT-backed aliases deliberately use explicit routes. This restores the
  # pre-e51f4680 behavior and avoids LiteLLM's wildcard segment substitution.
  mkChatgptEntry = id: {
    model_name = id;
    litellm_params = {
      model = "chatgpt/${id}";
    };
    model_info = {
      mode = "responses";
    };
  };

  chatgptEntries = map mkChatgptEntry chatgptModelIds;

  # When llama-swap is enabled on the same host, expose its enabled model IDs as
  # OpenAI-compatible routes to llama-swap's local endpoint. Model aliases equal
  # the llama-swap model keys.
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

  # LiteLLM proxy config as the upstream services.litellm.settings attrset
  # (rendered to YAML by the module). DB-free: master_key reads from litellm-env;
  # there is no database_url — LiteLLM runs stateless w.r.t. persistence.
  #
  # ChatGPT aliases use the prior explicit routes; Go routes generate from the
  # shared catalog; locally generated llama-swap entries append last.
  litellmSettings = {
    model_list = chatgptEntries ++ opencodeGoEntries ++ llamaSwapModelList;
    general_settings = {
      master_key = "os.environ/LITELLM_MASTER_KEY";
    };
    litellm_settings = {
      # Drop unrecognized provider params rather than failing.
      drop_params = true;
      # Conservative no-op; verify on 1.97.0 whether previous_response_id is
      # handled natively and drop this if so.
      additional_drop_params = [ "previous_response_id" ];
      # OpenTelemetry is Langfuse's current ingestion path; the legacy langfuse
      # callback uses an event API rejected by Langfuse v4.
      success_callback = [ "langfuse_otel" ];
      failure_callback = [ "langfuse_otel" ];
    };
  };

  # OPENAI_API_KEY env file for Karakeep, Paperless-GPT, and the Miniflux curator,
  # rendered at activation by litellm-openai-api-key-env from the single
  # LITELLM_MASTER_KEY inside litellm-env. The render enforces one simple
  # LITELLM_MASTER_KEY=sk-<ASCII token> assignment (fails closed on duplicates,
  # quotes, escapes, whitespace, CRLF, or multiline); the key is never in the
  # Nix store and is not duplicated across secrets.
  openaiApiKeyEnvFile = "/run/litellm-openai-api-key/openai-api-key-env";

  # Long-running units that read the rendered OPENAI_API_KEY file and must restart
  # when it changes. The Miniflux curator is absent: it is a timer oneshot that
  # re-reads its EnvironmentFile on every start, so a restart would fire an
  # off-schedule run. The paperless-gpt unit name is derived from the configured
  # OCI backend so switching podman/docker leaves no dangling target.
  keyConsumerUnits = [
    "karakeep-web.service"
    "karakeep-workers.service"
    "${config.virtualisation.oci-containers.backend}-paperless-gpt.service"
  ];
in
{
  # Upstream services.litellm, DB-free, master-key-only auth (single
  # LITELLM_MASTER_KEY). No database_url; no Postgres/ZFS dependency.
  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 8090;
    openFirewall = false;
    package = litellmPkg;
    stateDir = "/var/lib/litellm";

    # Non-secret vars only. PYTHONPATH carries the langfuse_otel runtime.
    environment = {
      STORE_PROMPTS_IN_SPEND_LOGS = "true";
      # The ChatGPT authenticator otherwise resolves its default ~/.config path
      # to /.config, which the hardened DynamicUser service cannot create.
      CHATGPT_TOKEN_DIR = "${config.services.litellm.stateDir}/chatgpt";
      PYTHONPATH = "${openTelemetryPython}/${openTelemetryPython.sitePackages}";
      LANGFUSE_HOST = "http://127.0.0.1:3000";
      LANGFUSE_OTEL_HOST = "http://127.0.0.1:3000";
      LANGFUSE_TRACING_ENVIRONMENT = "production";
      OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT = "span_and_event";
    };

    # litellm-env is the sole LiteLLM credential secret (master key, salt/UI,
    # provider, Langfuse); used directly as the service EnvironmentFile
    # (root-only read at activation, injected before dropping to DynamicUser).
    environmentFile = config.sops.secrets."litellm-env".path;

    settings = litellmSettings;
  };

  systemd.services =
    let
      # Consumers must not start before the OPENAI_API_KEY file exists. Rotation
      # is propagated via sops.secrets."litellm-env".restartUnits.
      consumerOrdering = lib.foldl' (
        acc: u:
        acc
        // {
          "${lib.removeSuffix ".service" u}" = {
            after = [ "litellm-openai-api-key-env.service" ];
            requires = [ "litellm-openai-api-key-env.service" ];
          };
        }
      ) { } keyConsumerUnits;
    in
    consumerOrdering
    // {
      # Reads litellm-env (the sole credential secret), validates exactly one
      # LITELLM_MASTER_KEY=sk-<ASCII token> assignment, and writes a root 0400
      # OPENAI_API_KEY env file. Fails closed on malformed input; the key is
      # neither duplicated across secrets nor written to the Nix store.
      "litellm-openai-api-key-env" = {
        description = "Render OPENAI_API_KEY env file from litellm-env master key";
        wantedBy = [ "multi-user.target" ];
        after = sopsUnits;
        requires = sopsUnits;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "litellm-openai-api-key";
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
        };
        script = ''
          set -eu
          src="${config.sops.secrets."litellm-env".path}"
          tmp="$(mktemp /run/litellm-openai-api-key/.openai-api-key-env.XXXXXX)"
          trap 'rm -f "$tmp"' EXIT

          # Strip CR so CRLF cannot smuggle a hidden character past the validator.
          # Count every assignment and well-formed simple tokens; reject if not
          # exactly one of each (duplicates, quoted/escaped/multiline forms fail closed).
          raw="$(${pkgs.coreutils}/bin/tr -d '\r' < "$src" \
            | ${pkgs.gnugrep}/bin/grep -cE '^LITELLM_MASTER_KEY=' || true)"
          good="$(${pkgs.coreutils}/bin/tr -d '\r' < "$src" \
            | ${pkgs.gnugrep}/bin/grep -cxE 'LITELLM_MASTER_KEY=sk-[A-Za-z0-9._~+/=-]+$' || true)"
          raw="''${raw:-0}"
          good="''${good:-0}"

          if [ "''$good" -ne 1 ] || [ "''$raw" -ne 1 ]; then
            echo "litellm-env must contain exactly one simple LITELLM_MASTER_KEY=sk-... assignment (no duplicates, quotes, escapes, whitespace, CRLF, or multiline); found raw=''$raw good=''$good" >&2
            exit 1
          fi

          val="$(${pkgs.coreutils}/bin/tr -d '\r' < "$src" \
            | ${pkgs.gnugrep}/bin/grep -Ex 'LITELLM_MASTER_KEY=sk-[A-Za-z0-9._~+/=-]+' \
            | ${pkgs.gnugrep}/bin/grep -Eo 'sk-[A-Za-z0-9._~+/=-]+$')"

          printf 'OPENAI_API_KEY=%s\n' "''$val" > "$tmp"
          chmod 0400 "$tmp"
          # Same filesystem rename: consumers see old or complete new file, never truncated.
          mv -f "$tmp" ${openaiApiKeyEnvFile}
          trap - EXIT
        '';
      };
    };

  # litellm-env is the sole LiteLLM credential secret; the gateway OPENAI_API_KEY
  # is derived from its LITELLM_MASTER_KEY (no second copy, no separate master-key
  # secret). restartUnits re-renders and restarts on real content changes only.
  sops.secrets."litellm-env".restartUnits = [
    "litellm-openai-api-key-env.service"
    "litellm.service"
  ]
  ++ keyConsumerUnits;

  # Guard against a dangling restart target: a restartUnits entry naming a unit
  # that no longer exists only fails at switch time. Catch it at evaluation.
  assertions =
    map
      (unit: {
        assertion = config.systemd.services ? ${lib.removeSuffix ".service" unit};
        message = "modules/nas/litellm: references ${unit}, but no such systemd service is defined on this host.";
      })
      (
        keyConsumerUnits
        ++ [
          "litellm-openai-api-key-env.service"
          "litellm.service"
        ]
      );

  # ai.homehub.tv → LiteLLM (127.0.0.1:8090); buffering off, long timeouts, no
  # websockets.
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
