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

    openaiHost = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:8080"; # Llama-cpp default
      description = "Embedding API host (OpenAI-compatible)";
    };

    embedModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen3-embedding-8b";
      description = "Embedding model for similarity scoring";
    };

    maxWorkers = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of parallel workers for embedding requests";
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
      path = [ curatorScript ];
      environment = {
        MINIFLUX_URL = cfg.minifluxUrl;
        OPENAI_HOST = cfg.openaiHost;
        EMBED_MODEL = cfg.embedModel;
        AUTO_MARK_READ_BELOW = toString cfg.autoMarkReadBelow;
        LIMIT_UNREAD = toString cfg.limitUnread;
        DRY_RUN = lib.boolToString cfg.dryRun;
        MAX_WORKERS = toString cfg.maxWorkers;
      };
      script = ''
        export MINIFLUX_API_KEY=$(cat ${cfg.apiKeyFile})
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
