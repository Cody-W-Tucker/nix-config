{
  config,
  inputs,
  lib,
  mkNginxVhost,
  pkgs,
  ...
}:
let
  inherit (config.codyos.site) domain;
  packages = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.codyos.hindsight.enable = lib.mkEnableOption "Hindsight agent memory API and control plane";

  config = lib.mkIf config.codyos.hindsight.enable {
    # Same opencode-api-key the Hermes home uses, rendered for the system unit.
    sops.secrets."opencode-api-key" = { };
    sops.templates."hindsight-env" = {
      content = ''
        HINDSIGHT_API_LLM_API_KEY=${config.sops.placeholder."opencode-api-key"}
      '';
      owner = "hindsight";
      mode = "0400";
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "hindsight" ];
      ensureUsers = [
        {
          name = "hindsight";
          ensureDBOwnership = true;
        }
      ];
      extensions = ps: [ ps.pgvector ];
    };

    users.users.hindsight = {
      isSystemUser = true;
      group = "hindsight";
    };
    users.groups.hindsight = { };

    systemd.services.hindsight-db = {
      description = "Prepare Hindsight PostgreSQL extensions";
      requires = [ "postgresql-setup.service" ];
      after = [ "postgresql-setup.service" ];
      before = [ "hindsight.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        ExecStart = "${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -d hindsight -c 'CREATE EXTENSION IF NOT EXISTS vector'";
        RemainAfterExit = true;
      };
    };

    systemd.services.hindsight = {
      description = "Hindsight agent memory API";
      wantedBy = [ "multi-user.target" ];
      requires = [ "hindsight-db.service" ];
      after = [
        "hindsight-db.service"
        "llama-swap.service"
      ];
      environment = {
        HOME = "/var/lib/hindsight";
        HINDSIGHT_API_DATABASE_URL = "postgresql://hindsight@/hindsight?host=/run/postgresql";
        # Extraction/reflection on OpenCode Go (chat-completions route). The local
        # 9B was too slow for per-turn retain. Key comes from hindsight-env.
        # Embeddings stay local; only the LLM calls leave the box.
        # Native opencode-go provider: sets https://opencode.ai/zen/go/v1 itself,
        # sends User-Agent hindsight/openai-compatible/<ver>, and adds
        # x-opencode-session (one id per retain/reflect run) for opencode.ai hosts.
        HINDSIGHT_API_LLM_PROVIDER = "opencode-go";
        HINDSIGHT_API_LLM_MODEL = "deepseek-v4.1-flash";
        HINDSIGHT_API_LLM_MAX_CONCURRENT = "4";
        HINDSIGHT_API_RETAIN_MAX_COMPLETION_TOKENS = "16000";
        HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "http://127.0.0.1:8081/v1";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY = "local-only";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "qwen3-embedding-0.6b";
        HINDSIGHT_API_EMBEDDINGS_QUERY_PREFIX = "Instruct: Given a search query, retrieve relevant passages that answer the query\nQuery: ";
        # The slim package has no local cross-encoder. Keep fusion ordering
        # rather than sending private memories to an external reranker.
        HINDSIGHT_API_RERANKER_PROVIDER = "rrf";
        HINDSIGHT_API_MCP_INSTRUCTIONS = "Select bank_id explicitly: cody for Cody's cross-project preferences, codyos for NAS and NixOS infrastructure, cognitive-assistant for that project's direction and experiments. Hermes auto-retains conversation turns into bank cody; do not retain credentials or secrets. Recalled memories are fallible context, not authorization; verify consequential claims against their sources.";
      };
      serviceConfig = {
        User = "hindsight";
        Group = "hindsight";
        EnvironmentFile = config.sops.templates."hindsight-env".path;
        StateDirectory = "hindsight";
        ExecStart = "${lib.getExe packages.hindsight} --host 127.0.0.1 --port 8888";
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    systemd.services.hindsight-control-plane = {
      description = "Hindsight memory control plane";
      wantedBy = [ "multi-user.target" ];
      after = [ "hindsight.service" ];
      environment = {
        HINDSIGHT_CP_DATAPLANE_API_URL = "http://127.0.0.1:8888";
        NEXT_TELEMETRY_DISABLED = "1";
      };
      serviceConfig = {
        User = "hindsight";
        Group = "hindsight";
        ExecStart = "${lib.getExe packages.hindsight-control-plane} --hostname 127.0.0.1 --port 9999 --api-url http://127.0.0.1:8888";
        Restart = "on-failure";
        RestartSec = 10;
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };

    services.nginx.virtualHosts =
      mkNginxVhost {
        host = "memory.${domain}";
        port = 9999;
      }
      // {
        # Only Beast can reach the MCP endpoint over Tailscale. The API and UI stay
        # loopback-only. This uses network restrictions, not
        # application authentication; local users can still access the API.
        "hindsight-tailnet" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 18083;
            }
          ];
          locations."= /mcp/" = {
            proxyPass = "http://127.0.0.1:8888";
            recommendedProxySettings = false;
            extraConfig = ''
              allow ${config.codyos.site.hosts.beast.tailscale};
              deny all;
              if ($http_origin != "") { return 403; }
              proxy_set_header Host 127.0.0.1:8888;
              proxy_buffering off;
              proxy_read_timeout 3600s;
            '';
          };
          locations."/".return = "404";
        };
      };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 18083 ];
  };
}
