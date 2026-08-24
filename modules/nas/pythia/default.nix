{
  config,
  pkgs,
  inputs,
  lib,
  mkNginxVhost,
  ...
}:

let
  cfg = config.services.pythia;
  pythiaPkg = import ./package.nix { inherit pkgs lib inputs; };
  # Interpreter with the engine + all its propagated deps on the path.
  engineEnv = pkgs.python3.withPackages (_: [ pythiaPkg ]);
in
{
  options.services.pythia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to run the PYTHIA oracle engine.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Interface the engine API binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8088;
      description = "Port the engine API listens on.";
    };

    llmBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8081/v1";
      description = ''
        OpenAI-compatible base URL for the oracle LLM. Defaults to the host's
        local llama-swap server (no LiteLLM proxy). Must expose
        /v1/chat/completions and /v1/models.
      '';
    };

    llmModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen-3.6-35b-a3b";
      description = "Model id the oracle requests from llama-swap (must be an enabled llama-swap model).";
    };

    osirisUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Osiris globe URL the engine fuses world feeds from. Leave null (the
        default) to disable the Osiris intake entirely — the engine emits no
        OSIRIS_URL and makes no connection attempts, so it will not silently
        probe localhost:3000. Set this to the deployed globe URL to enable it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.pythia = {
      isSystemUser = true;
      group = "pythia";
      description = "PYTHIA oracle engine";
      home = "/var/lib/pythia";
    };
    users.groups.pythia = { };

    systemd.services.pythia = {
      description = "PYTHIA oracle engine (FastAPI)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "llama-swap.service"
      ];
      wants = [ "llama-swap.service" ];
      serviceConfig = {
        Type = "simple";
        User = "pythia";
        Group = "pythia";
        StateDirectory = "pythia";
        WorkingDirectory = "/var/lib/pythia";
        ExecStart = "${engineEnv}/bin/python -m engine.run";
        Restart = "on-failure";
        RestartSec = "5s";

        # ── Hardening ──
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
        # uvicorn/fastapi need to exec + map; allow writes under StateDirectory only.
        MemoryDenyWriteExecute = false;
        # No EnvironmentFile: llama-swap is unauthenticated, so a fixed dummy
        # LLM_API_KEY (see `environment` below) satisfies the engine's Bearer header.
      };
      environment = {
        ENGINE_HOST = cfg.host;
        ENGINE_PORT = toString cfg.port;
        LLM_BASE_URL = cfg.llmBaseUrl;
        LLM_MODEL = cfg.llmModel;
        PYTHIA_RUNS_DIR = "/var/lib/pythia";
        # llama-swap has no auth; the engine still sends a Bearer key, so a
        # harmless fixed dummy satisfies it without a SOPS secret.
        LLM_API_KEY = "sk-noauth-local-llama-swap";
        # null ⇒ disable Osiris intake (empty URL is treated as disabled upstream).
        OSIRIS_URL = if cfg.osirisUrl != null then cfg.osirisUrl else "";
      };
    };

    # SSE streaming → buffering off, long timeouts.
    services.nginx.virtualHosts = mkNginxVhost {
      host = "pythia.homehub.tv";
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
