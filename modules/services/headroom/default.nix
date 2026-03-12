{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.headroom;

  defaultPackage = pkgs.callPackage ../../../packages/headroom-ai/package.nix { inherit pkgs; };

  command = lib.escapeShellArgs (
    [
      (lib.getExe cfg.package)
      "proxy"
      "--host"
      cfg.listenAddress
      "--port"
      (toString cfg.port)
      "--backend"
      cfg.backend
      "--anyllm-provider"
      cfg.anyllmProvider
      "--region"
      cfg.region
    ]
    ++ lib.optionals (!cfg.optimize) [ "--no-optimize" ]
    ++ lib.optionals (!cfg.cache) [ "--no-cache" ]
    ++ lib.optionals (!cfg.rateLimit) [ "--no-rate-limit" ]
    ++ lib.optionals (!cfg.llmlingua) [ "--no-llmlingua" ]
    ++ lib.optionals (!cfg.codeAware) [ "--no-code-aware" ]
    ++ lib.optionals (!cfg.readLifecycle) [ "--no-read-lifecycle" ]
    ++ lib.optionals (!cfg.intelligentContext) [ "--no-intelligent-context" ]
    ++ lib.optionals (!cfg.intelligentScoring) [ "--no-intelligent-scoring" ]
    ++ lib.optionals (!cfg.compressFirst) [ "--no-compress-first" ]
    ++ lib.optionals (cfg.logFile != null) [
      "--log-file"
      cfg.logFile
    ]
    ++ lib.optionals (cfg.budget != null) [
      "--budget"
      (toString cfg.budget)
    ]
    ++ lib.optionals cfg.memory.enable [
      "--memory"
      "--memory-db-path"
      cfg.memory.dbPath
      "--memory-top-k"
      (toString cfg.memory.topK)
    ]
    ++ lib.optionals (cfg.memory.enable && !cfg.memory.injectTools) [ "--no-memory-tools" ]
    ++ lib.optionals (cfg.memory.enable && !cfg.memory.injectContext) [ "--no-memory-context" ]
    ++ lib.optionals (cfg.bedrockProfile != null) [
      "--bedrock-profile"
      cfg.bedrockProfile
    ]
    ++ cfg.extraArgs
  );
in
{
  options.services.headroom = {
    enable = lib.mkEnableOption "Headroom LLM optimization proxy";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Headroom package that provides the `headroom` CLI.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address for the Headroom proxy to bind to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Port for the Headroom proxy.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the Headroom port in the firewall.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/headroom";
      description = "Directory used for Headroom state, logs, and memory storage.";
    };

    backend = lib.mkOption {
      type = lib.types.str;
      default = "anthropic";
      description = "Backend passed to `headroom proxy --backend`.";
    };

    anyllmProvider = lib.mkOption {
      type = lib.types.str;
      default = "openai";
      description = "Provider used when `services.headroom.backend = \"anyllm\"`.";
    };

    region = lib.mkOption {
      type = lib.types.str;
      default = "us-west-2";
      description = "Cloud region passed to Headroom for Bedrock or Vertex style backends.";
    };

    bedrockProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional AWS profile name for Bedrock requests.";
    };

    budget = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = null;
      description = "Optional daily budget limit in USD.";
    };

    logFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional JSONL log file path passed to Headroom.";
    };

    optimize = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to keep Headroom optimization enabled.";
    };

    cache = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to keep Headroom semantic caching enabled.";
    };

    rateLimit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to keep Headroom rate limiting enabled.";
    };

    llmlingua = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable LLMLingua compression support.";
    };

    codeAware = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to keep AST-aware code compression enabled.";
    };

    readLifecycle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to keep read lifecycle compression enabled.";
    };

    intelligentContext = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to keep intelligent context management enabled.";
    };

    intelligentScoring = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to keep intelligent context scoring enabled.";
    };

    compressFirst = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to let Headroom try deeper compression before dropping context.";
    };

    memory = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable Headroom persistent memory support.";
      };

      dbPath = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/headroom-memory.db";
        description = "Path to the Headroom memory database.";
      };

      topK = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Number of memories Headroom injects into context.";
      };

      injectTools = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to inject Headroom memory tools into requests.";
      };

      injectContext = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to inject retrieved memory context into requests.";
      };
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional environment file for API keys or backend-specific configuration.";
    };

    serviceEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the Headroom systemd service.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments appended to `headroom proxy`.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.headroom = { };

    users.users.headroom = {
      isSystemUser = true;
      group = "headroom";
      home = cfg.dataDir;
      createHome = false;
    };

    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.port ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 headroom headroom - -"
    ];

    systemd.services.headroom = {
      description = "Headroom LLM optimization proxy";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = cfg.dataDir;
      } // cfg.serviceEnvironment;

      serviceConfig = {
        User = "headroom";
        Group = "headroom";
        WorkingDirectory = cfg.dataDir;
        ExecStart = command;
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };
    };
  };
}
