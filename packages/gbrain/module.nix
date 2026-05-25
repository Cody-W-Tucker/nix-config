{
  config,
  lib,
  osConfig,
  pkgs,
  self,
  ...
}:

let
  defaultSearchMode = "conservative";
  defaultMcpPort = 3131;
  defaultMcpTokenName = "gbrain-local-mcp";
  defaultEmbeddingModelId = "qwen3-embedding-0.6b";
  defaultEmbeddingModel = "llama-server:qwen3-embedding-0.6b";
  systemCfg = osConfig.services.gbrain or { };
  systemGbrainEnabled = systemCfg.enable or false;
  cfg = config.services.gbrain;
  gbrainPkg = self.packages.${pkgs.stdenv.hostPlatform.system}.gbrain;
  gbrainBootstrap = pkgs.callPackage ./bootstrap.nix { inherit gbrainPkg; };
  llamaSwapPort = toString (osConfig.services.llama-swap.port or 8080);
  detectedLlamaServerBaseUrl = "http://127.0.0.1:${llamaSwapPort}/v1";
  hasDetectedEmbeddings = lib.elem defaultEmbeddingModelId (
    osConfig.services.llama-swap.enabledModels or [ ]
  );
  gbrainRoot = cfg.root;
  gbrainHome = cfg.home;
  gbrainMcpMode =
    if cfg.mcp.mode != null then
      cfg.mcp.mode
    else if cfg.databaseUrl != null then
      "remote"
    else
      "local";
  llamaServerBaseUrl =
    if cfg.llamaServerBaseUrl != null then
      cfg.llamaServerBaseUrl
    else if hasDetectedEmbeddings then
      detectedLlamaServerBaseUrl
    else
      null;
  embeddingModel =
    if cfg.embeddingModel != null then
      cfg.embeddingModel
    else if llamaServerBaseUrl != null then
      defaultEmbeddingModel
    else
      null;
  embeddingDimensions = if cfg.embeddingDimensions != null then cfg.embeddingDimensions else null;
  environmentFile = cfg.environmentFile;
  providerBaseUrls = cfg.providerBaseUrls;
  runtimeConfig = cfg.runtimeConfig;
  mcpEnvFile = "${config.xdg.configHome}/environment.d/90-gbrain.conf";
  gbrainMcpUrl = "http://127.0.0.1:${toString cfg.mcp.port}/mcp";
  shellEnvFiles = lib.filter (path: path != null) [
    environmentFile
    (if cfg.databaseUrl != null then mcpEnvFile else null)
  ];
  bootstrapEnv = [
    "GBRAIN_ROOT=${lib.escapeShellArg gbrainRoot}"
    "GBRAIN_HOME=${lib.escapeShellArg gbrainHome}"
    "GBRAIN_SEARCH_MODE=${lib.escapeShellArg cfg.searchMode}"
  ]
  ++ lib.optional (
    cfg.databaseUrl != null
  ) "GBRAIN_DATABASE_URL=${lib.escapeShellArg cfg.databaseUrl}"
  ++ lib.optional (cfg.databaseUrl != null) "PGHOST=/run/postgresql"
  ++ lib.optional (cfg.databaseUrl != null) "GBRAIN_MCP_ENV_FILE=${lib.escapeShellArg mcpEnvFile}"
  ++ lib.optional (
    cfg.databaseUrl != null
  ) "GBRAIN_MCP_TOKEN_NAME=${lib.escapeShellArg cfg.mcp.tokenName}"
  ++
    lib.optional (cfg.databaseUrl != null)
      "GBRAIN_PSQL_BIN=${lib.escapeShellArg (lib.getExe' osConfig.services.postgresql.finalPackage "psql")}"
  ++ lib.optional (
    llamaServerBaseUrl != null
  ) "LLAMA_SERVER_BASE_URL=${lib.escapeShellArg llamaServerBaseUrl}"
  ++ lib.optional (
    embeddingModel != null
  ) "GBRAIN_EMBEDDING_MODEL=${lib.escapeShellArg embeddingModel}"
  ++ lib.optional (
    embeddingDimensions != null
  ) "GBRAIN_EMBEDDING_DIMENSIONS=${lib.escapeShellArg (toString embeddingDimensions)}";
  localMcpEnv = {
    GBRAIN_HOME = gbrainHome;
  }
  // lib.optionalAttrs (cfg.databaseUrl != null) {
    GBRAIN_DATABASE_URL = cfg.databaseUrl;
    PGHOST = "/run/postgresql";
  }
  // lib.optionalAttrs (llamaServerBaseUrl != null) {
    LLAMA_SERVER_BASE_URL = llamaServerBaseUrl;
  };
in
{
  options.services.gbrain = {
    enable = lib.mkEnableOption "GBrain knowledge base";

    root = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Knowledge/GBrain";
      description = "Root directory for the GBrain repository.";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/gbrain";
      description = "Runtime state directory for GBrain config, tokens, and local data.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if systemGbrainEnabled then systemCfg.environmentFile else null;
      description = "Optional environment file sourced by shells and GBrain services for provider credentials and related runtime config.";
    };

    databaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if systemGbrainEnabled then systemCfg.databaseUrl else null;
      description = "Postgres connection string. Leave null to use PGLite.";
    };

    searchMode = lib.mkOption {
      type = lib.types.str;
      default = defaultSearchMode;
      description = "GBrain search mode written during bootstrap.";
    };

    llamaServerBaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if systemGbrainEnabled then systemCfg.llamaServerBaseUrl else null;
      description = "Override the llama-server base URL for local embeddings.";
    };

    embeddingModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if systemGbrainEnabled then systemCfg.embeddingModel else null;
      description = "Embedding model to initialize GBrain with.";
    };

    embeddingDimensions = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = if systemGbrainEnabled then systemCfg.embeddingDimensions else null;
      description = "Embedding dimensions to initialize GBrain with.";
    };

    chatModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional chat model written to GBrain config during bootstrap.";
    };

    factsExtractionModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional facts extraction model written to GBrain config during bootstrap.";
    };

    providerBaseUrls = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Optional file-plane provider base URL overrides written into GBrain config.json.";
    };

    runtimeConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "DB-plane GBrain config keys to apply during bootstrap, e.g. models.chat or models.expansion.";
    };

    mcp = {
      mode = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "local"
            "remote"
          ]
        );
        default = if systemGbrainEnabled then "remote" else null;
        description = "How OpenCode connects to GBrain MCP.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = if systemGbrainEnabled then systemCfg.mcp.port else defaultMcpPort;
        description = "HTTP port for the always-on GBrain MCP service.";
      };

      tokenName = lib.mkOption {
        type = lib.types.str;
        default = if systemGbrainEnabled then systemCfg.mcp.tokenName else defaultMcpTokenName;
        description = "Token name stored in GBrain for remote MCP access.";
      };

      systemService = lib.mkOption {
        type = lib.types.bool;
        default = systemGbrainEnabled;
        description = "Run the always-on GBrain MCP server as a system service instead of a user service.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = gbrainMcpMode != "remote" || cfg.databaseUrl != null;
        message = "services.gbrain.mcp.mode = remote requires services.gbrain.databaseUrl.";
      }
      {
        assertion = embeddingDimensions == null || embeddingModel != null;
        message = "services.gbrain.embeddingDimensions requires services.gbrain.embeddingModel.";
      }
    ];

    home.packages = [ gbrainPkg ];

    home.sessionVariables = {
      GBRAIN_HOME = gbrainHome;
    }
    // lib.optionalAttrs (cfg.databaseUrl != null) {
      GBRAIN_DATABASE_URL = cfg.databaseUrl;
      PGHOST = "/run/postgresql";
    }
    // lib.optionalAttrs (llamaServerBaseUrl != null) {
      LLAMA_SERVER_BASE_URL = llamaServerBaseUrl;
    };

    programs.bash.initExtra = lib.mkIf (shellEnvFiles != [ ]) (
      lib.concatMapStringsSep "\n" (path: ''
        if [ -f ${lib.escapeShellArg path} ]; then
          set -a
          . ${lib.escapeShellArg path}
          set +a
        fi
      '') shellEnvFiles
    );

    programs.zsh.initContent = lib.mkIf (shellEnvFiles != [ ]) (
      lib.concatMapStringsSep "\n" (path: ''
        if [ -f ${lib.escapeShellArg path} ]; then
          set -a
          source ${lib.escapeShellArg path}
          set +a
        fi
      '') shellEnvFiles
    );

    home.activation.gbrainBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatMapStringsSep "\n" (entry: "export ${entry}") bootstrapEnv
      + "\n"
      + lib.optionalString (environmentFile != null) ''
        if [ -f ${lib.escapeShellArg environmentFile} ]; then
          set -a
          . ${lib.escapeShellArg environmentFile}
          set +a
        fi
      ''
      + ''
        ${lib.getExe gbrainBootstrap}
      ''
      + lib.optionalString (cfg.chatModel != null || providerBaseUrls != { }) ''
        ${lib.getExe' pkgs.bun "bun"} -e '
          const fs = require("fs");
          const path = process.argv[1];
          const chatModel = process.argv[2];
          const baseUrls = JSON.parse(process.argv[3]);
          const cfg = JSON.parse(fs.readFileSync(path, "utf8"));
          if (chatModel !== "") cfg.chat_model = chatModel;
          if (Object.keys(baseUrls).length > 0) cfg.provider_base_urls = { ...(cfg.provider_base_urls || {}), ...baseUrls };
          fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + "\n");
        ' ${lib.escapeShellArg "${gbrainHome}/.gbrain/config.json"} ${
          lib.escapeShellArg (if cfg.chatModel != null then cfg.chatModel else "")
        } ${lib.escapeShellArg (builtins.toJSON providerBaseUrls)}
      ''
      + lib.optionalString (cfg.chatModel != null) ''
        GBRAIN_HOME=${lib.escapeShellArg gbrainHome} ${lib.getExe gbrainPkg} config set chat_model ${lib.escapeShellArg cfg.chatModel}
      ''
      + lib.optionalString (cfg.factsExtractionModel != null) ''
        GBRAIN_HOME=${lib.escapeShellArg gbrainHome} ${lib.getExe gbrainPkg} config set facts.extraction_model ${lib.escapeShellArg cfg.factsExtractionModel}
      ''
      + lib.concatMapStringsSep "\n" (key: ''
        GBRAIN_HOME=${lib.escapeShellArg gbrainHome} ${lib.getExe gbrainPkg} config set ${lib.escapeShellArg key} ${
          lib.escapeShellArg runtimeConfig.${key}
        }
      '') (builtins.attrNames runtimeConfig)
    );

    systemd.user.services.gbrain-mcp = lib.mkIf (gbrainMcpMode == "remote" && !cfg.mcp.systemService) {
      Unit = {
        Description = "Always-on GBrain MCP service";
        After = [ "default.target" ];
      };
      Service = {
        ExecStart = "${lib.getExe gbrainPkg} serve --http --port ${toString cfg.mcp.port}";
        Restart = "always";
        RestartSec = 5;
        EnvironmentFile = lib.optional (environmentFile != null) environmentFile;
        Environment = [
          "GBRAIN_HOME=${gbrainHome}"
          "GBRAIN_DATABASE_URL=${cfg.databaseUrl}"
          "PGHOST=/run/postgresql"
        ]
        ++ lib.optional (llamaServerBaseUrl != null) "LLAMA_SERVER_BASE_URL=${llamaServerBaseUrl}";
      };
      Install.WantedBy = [ "default.target" ];
    };

    programs.opencode.settings.mcp.gbrain = {
      type = "local";
      command = [
        (lib.getExe gbrainPkg)
        "serve"
      ];
      enabled = true;
      env = localMcpEnv;
    };
  };
}
