{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.miniflux-curator;
  curatorScript = import ./script.nix { inherit pkgs inputs; };
in

{
  options.services.miniflux-curator = {
    enable = lib.mkEnableOption "Miniflux auto-curator service";

    minifluxUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:7777";
      description = "Miniflux instance URL";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing Miniflux API key";
    };

    karakeepUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:3000";
      description = "Karakeep instance URL";
    };

    karakeepApiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing Karakeep API key";
    };

    openaiHost = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:8080"; # Llama-cpp default
      description = "Embedding API host (OpenAI-compatible)";
    };

    openaiApiKeyEnvFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a systemd EnvironmentFile that defines `OPENAI_API_KEY=<key>` for the
        embedding/gateway host. This is an env file, not a bare key file — supply a
        rendered SOPS template rather than a raw secret, so the KEY=VALUE shape is
        guaranteed. May be root-owned 0400: systemd reads EnvironmentFile= as the
        service manager before dropping to User=.
      '';
    };

    embedModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen3-embedding-8b";
      description = "Embedding model for similarity scoring";
    };

    batchSize = lib.mkOption {
      type = lib.types.int;
      default = 64;
      description = "Number of articles to embed per batch request (default: 64)";
    };

    karakeepFetchLimit = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Number of recent Karakeep bookmarks to fetch before reference selection";
    };

    referenceLimit = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Maximum Karakeep bookmarks selected for reference embeddings";
    };

    autoMarkReadBelow = lib.mkOption {
      type = lib.types.float;
      default = 3.5;
      description = "Score threshold below which entries are marked as read (0-10)";
    };

    limitUnread = lib.mkOption {
      type = lib.types.int;
      default = 400;
      description = "Maximum unread entries to process per run";
    };

    dryRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When true, only logs what would be done without making changes";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Schedule for running the curator (systemd timer format)";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.miniflux-curator = {
      description = "Miniflux RSS Auto-Curator";
      serviceConfig = {
        Type = "oneshot";
        User = "miniflux-curator";
        Group = "miniflux-curator";
        WorkingDirectory = "/var/lib/miniflux-curator";
      };
      # OPENAI_API_KEY for the LiteLLM gateway. systemd reads the file as the service
      # manager (root) and injects it before dropping to User=miniflux-curator, so the
      # env file needs no group/other read access.
      serviceConfig.EnvironmentFile = [ cfg.openaiApiKeyEnvFile ];
      path = [ curatorScript ];
      environment = {
        MINIFLUX_URL = cfg.minifluxUrl;
        KARAKEEP_URL = cfg.karakeepUrl;
        OPENAI_HOST = cfg.openaiHost;
        EMBED_MODEL = cfg.embedModel;
        AUTO_MARK_READ_BELOW = toString cfg.autoMarkReadBelow;
        LIMIT_UNREAD = toString cfg.limitUnread;
        DRY_RUN = lib.boolToString cfg.dryRun;
        BATCH_SIZE = toString cfg.batchSize;
        KARAKEEP_FETCH_LIMIT = toString cfg.karakeepFetchLimit;
        REFERENCE_LIMIT = toString cfg.referenceLimit;
        STATE_FILE = "/var/lib/miniflux-curator/state.json";
      };
      script = ''
        export MINIFLUX_API_KEY=$(cat ${cfg.apiKeyFile})
        export KARAKEEP_API_KEY=$(cat ${cfg.karakeepApiKeyFile})
        miniflux-curator
      '';
      startAt = cfg.schedule;
    };

    # Create dedicated user
    users.users.miniflux-curator = {
      isSystemUser = true;
      group = "miniflux-curator";
      home = "/var/lib/miniflux-curator";
      createHome = true;
    };
    users.groups.miniflux-curator = { };

    # Ensure working directory exists with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/miniflux-curator 0750 miniflux-curator miniflux-curator -"
    ];
  };
}
