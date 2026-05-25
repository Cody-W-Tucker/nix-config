{
  config,
  lib,
  pkgs,
  self,
  ...
}:

let
  cfg = config.services.gbrain;
  homeManagerUsers = lib.attrNames (config.home-manager.users or { });
  defaultUser = if lib.length homeManagerUsers == 1 then lib.head homeManagerUsers else "codyt";
  gbrainUser = cfg.user;
  gbrainGroup = cfg.group;
  gbrainHomeDir = config.users.users.${gbrainUser}.home;
  gbrainStateDir = cfg.home;
  gbrainEnvironmentFile = cfg.environmentFile;
  gbrainPkg = self.packages.${pkgs.stdenv.hostPlatform.system}.gbrain;
  gbrainDatabaseUrl = cfg.databaseUrl;
  gbrainLlamaServerBaseUrl = cfg.llamaServerBaseUrl;
  gbrainEmbeddingModel = cfg.embeddingModel;
  gbrainEmbeddingDimensions = cfg.embeddingDimensions;
  gbrainPostgresBootstrap = pkgs.writeShellApplication {
    name = "gbrain-postgres-bootstrap";
    runtimeInputs = [
      config.services.postgresql.finalPackage
    ];
    text = ''
      set -eu

      psql -d postgres -c 'ALTER ROLE ${gbrainUser} BYPASSRLS;'

      psql -d ${gbrainUser} -c 'CREATE EXTENSION IF NOT EXISTS vector;'

      psql -v ON_ERROR_STOP=1 -d ${gbrainUser} <<'SQL'
      DO $$
      DECLARE
        obj RECORD;
      BEGIN
        FOR obj IN
          SELECT c.relname
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'public'
            AND c.relkind = 'r'
            AND pg_get_userbyid(c.relowner) = 'postgres'
        LOOP
          EXECUTE format(
            'ALTER TABLE public.%I OWNER TO ${gbrainUser}',
            obj.relname
          );
        END LOOP;
      END $$;
      SQL
    '';
  };
  gbrainSchemaBootstrap = pkgs.writeShellApplication {
    name = "gbrain-schema-bootstrap";
    runtimeInputs = [
      gbrainPkg
      pkgs.coreutils
    ];
    text = ''
      set -eu

      tmp_home="$(mktemp -d)"
      trap 'rm -rf "$tmp_home"' EXIT

      json_escape() {
        local value="$1"
        value=''${value//\\/\\\\}
        value=''${value//\"/\\\"}
        value=''${value//$'\n'/\\n}
        value=''${value//$'\r'/\\r}
        value=''${value//$'\t'/\\t}
        printf '%s' "$value"
      }

      mkdir -p "$tmp_home/.gbrain"
      chmod 700 "$tmp_home"

      {
        printf '{\n'
        printf '  "engine": "postgres",\n'
        printf '  "database_url": "%s",\n' "$(json_escape "${gbrainDatabaseUrl}")"
        printf '  "embedding_model": "%s",\n' "$(json_escape "${gbrainEmbeddingModel}")"
        printf '  "embedding_dimensions": %s\n' ${toString gbrainEmbeddingDimensions}
        printf '}\n'
      } > "$tmp_home/.gbrain/config.json"
      chmod 600 "$tmp_home/.gbrain/config.json"

      GBRAIN_HOME="$tmp_home" \
        PGHOST=/run/postgresql \
        LLAMA_SERVER_BASE_URL="${gbrainLlamaServerBaseUrl}" \
        gbrain init --migrate-only
    '';
  };
in
{
  options.services.gbrain = {
    enable = lib.mkEnableOption "system GBrain services";

    user = lib.mkOption {
      type = lib.types.str;
      default = defaultUser;
      description = "User that owns GBrain runtime state and runs the MCP service.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = config.users.users.${gbrainUser}.group or "users";
      description = "Group for GBrain system services.";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "${gbrainHomeDir}/.local/share/gbrain";
      description = "Runtime state directory for GBrain config and tokens.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional environment file loaded by the system GBrain MCP service for provider credentials and related runtime config.";
    };

    databaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "postgresql:///${gbrainUser}";
      description = "Postgres connection string used by system GBrain services.";
    };

    llamaServerBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${toString (config.services.llama-swap.port or 8081)}/v1";
      description = "llama-server base URL used for local embeddings.";
    };

    embeddingModel = lib.mkOption {
      type = lib.types.str;
      default = "llama-server:qwen3-embedding-0.6b";
      description = "Embedding model to initialize the Postgres GBrain schema with.";
    };

    embeddingDimensions = lib.mkOption {
      type = lib.types.int;
      default = 1024;
      description = "Embedding dimensions to initialize the Postgres GBrain schema with.";
    };

    mcp = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 3131;
        description = "HTTP port for the system GBrain MCP service.";
      };

      tokenName = lib.mkOption {
        type = lib.types.str;
        default = "gbrain-local-mcp";
        description = "Token name stored in GBrain for remote MCP access.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      extensions = ps: [ ps.pgvector ];
      ensureDatabases = [ gbrainUser ];
      ensureUsers = [
        {
          name = gbrainUser;
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.services.gbrain-postgres-bootstrap = {
      description = "Prepare Postgres role and extensions for GBrain";
      after = [
        "postgresql.service"
        "postgresql-setup.service"
      ];
      requires = [
        "postgresql.service"
        "postgresql-setup.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
        ExecStart = lib.getExe gbrainPostgresBootstrap;
      };
    };

    systemd.services.gbrain-schema-bootstrap = {
      description = "Run GBrain schema migrations as app user";
      after = [
        "postgresql.service"
        "postgresql-setup.service"
        "gbrain-postgres-bootstrap.service"
      ];
      requires = [
        "postgresql.service"
        "postgresql-setup.service"
        "gbrain-postgres-bootstrap.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = gbrainUser;
        Group = gbrainGroup;
        ExecStart = lib.getExe gbrainSchemaBootstrap;
      };
    };

    systemd.services."home-manager-${gbrainUser}" = {
      after = [ "gbrain-schema-bootstrap.service" ];
      requires = [ "gbrain-schema-bootstrap.service" ];
    };

    systemd.services.gbrain-mcp = {
      description = "Always-on GBrain MCP service";
      after = [
        "network.target"
        "postgresql.service"
        "home-manager-${gbrainUser}.service"
        "gbrain-schema-bootstrap.service"
      ];
      requires = [ "gbrain-schema-bootstrap.service" ];
      wants = [ "home-manager-${gbrainUser}.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = gbrainUser;
        Group = gbrainGroup;
        WorkingDirectory = gbrainHomeDir;
        Restart = "always";
        RestartSec = 5;
        ExecStart = "${lib.getExe gbrainPkg} serve --http --port ${toString cfg.mcp.port}";
        EnvironmentFile = lib.optional (gbrainEnvironmentFile != null) gbrainEnvironmentFile;
      };
      environment = {
        GBRAIN_HOME = gbrainStateDir;
        GBRAIN_DATABASE_URL = gbrainDatabaseUrl;
        PGHOST = "/run/postgresql";
        LLAMA_SERVER_BASE_URL = gbrainLlamaServerBaseUrl;
      };
    };

    systemd.services.hermes-agent = lib.mkIf config.services.hermes-agent.enable {
      after = [ "gbrain-mcp.service" ];
      wants = [ "gbrain-mcp.service" ];
    };
  };
}
